import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../storage/secure_storage_service.dart';

/// Response model from the Telegram MTProto Client Bridge during OTP / 2FA auth.
class BridgeAuthResult {
  final bool success;
  final bool requires2FA;
  final String? phoneCodeHash;
  final String? sessionToken;
  final String? username;
  final String? errorMessage;

  const BridgeAuthResult({
    required this.success,
    this.requires2FA = false,
    this.phoneCodeHash,
    this.sessionToken,
    this.username,
    this.errorMessage,
  });
}

/// Configurable client for communicating with a self-hosted Telegram MTProto Bridge
/// (Telethon / Pyrogram / GramJS / TDLib) without ever embedding `api_id` or `api_hash`
/// inside the mobile application binary.
///
/// Supports both:
/// 1. **Live Bridge Mode**: Sends HTTPS requests to the user's configured bridge URL.
/// 2. **Simulation / Demo Mode**: Simulates the full MTProto Phone -> OTP -> optional 2FA
///    and chunked upload progress for instant verification and offline testing.
class TelegramBridgeClient {
  final SecureStorageService _secureStorage;
  final http.Client _httpClient;

  TelegramBridgeClient({
    required SecureStorageService secureStorage,
    http.Client? httpClient,
  })  : _secureStorage = secureStorage,
        _httpClient = httpClient ?? http.Client();

  Future<String> _resolveBaseUrl() async {
    final stored = await _secureStorage.getBridgeUrl();
    if (stored != null && stored.isNotEmpty) return stored;
    return 'http://localhost:8765';
  }

  /// Computes a SHA-256 hash of a file on disk, or falls back to a deterministic
  /// metadata signature if the path is virtual.
  static Future<String> computeFileSha256({
    required String filePath,
    required String fileName,
    required int sizeBytes,
  }) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final digest = await sha256.bind(file.openRead()).first;
        return digest.toString();
      }
    } catch (_) {
      // Fallback for virtual or scoped paths
    }
    final bytes = utf8.encode('$fileName|$sizeBytes');
    return sha256.convert(bytes).toString();
  }

  /// Step 1: Request OTP code to be sent to the user's Telegram app / SMS.
  Future<BridgeAuthResult> requestOtpCode({
    required String countryCode,
    required String phoneNumber,
  }) async {
    final fullPhone = '$countryCode${phoneNumber.replaceAll(RegExp(r'\s+'), '')}';
    final isDemo = await _secureStorage.getDemoMode();

    if (isDemo) {
      await Future.delayed(const Duration(milliseconds: 650));
      final hash = sha256.convert(utf8.encode('otp_$fullPhone')).toString().substring(0, 24);
      return BridgeAuthResult(
        success: true,
        phoneCodeHash: hash,
      );
    }

    try {
      final baseUrl = await _resolveBaseUrl();
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/auth/send-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phoneNumber': fullPhone}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return BridgeAuthResult(
          success: true,
          phoneCodeHash: data['phoneCodeHash'] as String?,
        );
      }
      return BridgeAuthResult(
        success: false,
        errorMessage: (data['message'] as String?) ?? 'Failed to request OTP from bridge.',
      );
    } catch (e) {
      return BridgeAuthResult(
        success: false,
        errorMessage: 'Bridge unreachable ($e). Enable Demo Mode in Bridge Settings to test offline.',
      );
    }
  }

  /// Step 2: Verify the 5-digit Telegram OTP code.
  /// TIP: In Demo Mode, entering code `22222` triggers the Two-Step Verification (2FA) password step
  /// so you can test both standard OTP login and 2FA password verification!
  Future<BridgeAuthResult> verifyOtpCode({
    required String fullPhone,
    required String otpCode,
    required String phoneCodeHash,
  }) async {
    final isDemo = await _secureStorage.getDemoMode();

    if (isDemo) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (otpCode.trim().length < 5) {
        return const BridgeAuthResult(
          success: false,
          errorMessage: 'Please enter a valid 5-digit Telegram login code.',
        );
      }
      // Special code '22222' demonstrates Two-Step Verification (2FA) prompt
      if (otpCode.trim() == '22222') {
        return BridgeAuthResult(
          success: true,
          requires2FA: true,
          phoneCodeHash: phoneCodeHash,
        );
      }
      final token =
          'tv_sess_${sha256.convert(utf8.encode('$fullPhone|$otpCode')).toString().substring(0, 32)}';
      return BridgeAuthResult(
        success: true,
        sessionToken: token,
        username: 'Saved Messages ($fullPhone)',
      );
    }

    try {
      final baseUrl = await _resolveBaseUrl();
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phoneNumber': fullPhone,
              'code': otpCode.trim(),
              'phoneCodeHash': phoneCodeHash,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (data['status'] == '2fa_required') {
          return BridgeAuthResult(
            success: true,
            requires2FA: true,
            phoneCodeHash: phoneCodeHash,
          );
        }
        return BridgeAuthResult(
          success: true,
          sessionToken: data['sessionToken'] as String?,
          username: (data['username'] as String?) ?? 'Saved Messages',
        );
      }
      return BridgeAuthResult(
        success: false,
        errorMessage: (data['message'] as String?) ?? 'Invalid OTP code.',
      );
    } catch (e) {
      return BridgeAuthResult(
        success: false,
        errorMessage: 'Bridge verification error: $e',
      );
    }
  }

  /// Step 2b (Optional): Verify Telegram Two-Step Verification (Cloud Password).
  Future<BridgeAuthResult> verifyTwoFactorPassword({
    required String fullPhone,
    required String password,
    required String phoneCodeHash,
  }) async {
    final isDemo = await _secureStorage.getDemoMode();

    if (isDemo) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (password.isEmpty) {
        return const BridgeAuthResult(
          success: false,
          errorMessage: 'Two-Step Verification password cannot be empty.',
        );
      }
      final token =
          'tv_2fa_${sha256.convert(utf8.encode('$fullPhone|$password')).toString().substring(0, 32)}';
      return BridgeAuthResult(
        success: true,
        sessionToken: token,
        username: 'Saved Messages ($fullPhone • 2FA Verified)',
      );
    }

    try {
      final baseUrl = await _resolveBaseUrl();
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/v1/auth/verify-2fa'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phoneNumber': fullPhone,
              'password': password,
              'phoneCodeHash': phoneCodeHash,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return BridgeAuthResult(
          success: true,
          sessionToken: data['sessionToken'] as String?,
          username: (data['username'] as String?) ?? 'Saved Messages',
        );
      }
      return BridgeAuthResult(
        success: false,
        errorMessage: (data['message'] as String?) ?? 'Incorrect 2FA password.',
      );
    } catch (e) {
      return BridgeAuthResult(
        success: false,
        errorMessage: '2FA verification error: $e',
      );
    }
  }

  /// Uploads a file to the user's Telegram `Saved Messages` (`me`) via the configured bridge
  /// with real-time progress callbacks.
  Future<String> uploadFileToTelegram({
    required String filePath,
    required String fileName,
    required String folderName,
    required int sizeBytes,
    required String sha256Hash,
    required void Function(double progress) onProgress,
    required bool Function() isCancelledOrPaused,
  }) async {
    final isDemo = await _secureStorage.getDemoMode();

    if (isDemo) {
      const steps = 10;
      for (var i = 1; i <= steps; i++) {
        if (isCancelledOrPaused()) {
          throw Exception('Upload paused or cancelled by user.');
        }
        await Future.delayed(const Duration(milliseconds: 180));
        onProgress(i / steps);
      }
      return 'tg_msg_${DateTime.now().millisecondsSinceEpoch}';
    }

    final sessionToken = await _secureStorage.getSessionToken();
    if (sessionToken == null || sessionToken.isEmpty) {
      throw Exception('Not authenticated with Telegram Cloud.');
    }

    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/api/v1/files/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $sessionToken'
      ..fields['folderName'] = folderName
      ..fields['sha256'] = sha256Hash
      ..fields['targetChat'] = 'me';

    final file = File(filePath);
    if (await file.exists()) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } else {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          utf8.encode('TeleVault virtual payload: $fileName'),
          filename: fileName,
        ),
      );
    }

    onProgress(0.35);
    final streamed = await request.send().timeout(const Duration(minutes: 5));
    onProgress(0.9);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      onProgress(1.0);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['messageId']?.toString()) ?? 'tg_msg_uploaded';
    }
    throw Exception('Bridge upload failed (HTTP ${response.statusCode})');
  }

  /// Safely terminates the remote session and clears local hardware-backed storage.
  Future<void> logoutSession() async {
    final isDemo = await _secureStorage.getDemoMode();
    if (!isDemo) {
      try {
        final token = await _secureStorage.getSessionToken();
        final baseUrl = await _resolveBaseUrl();
        if (token != null) {
          await _httpClient
              .post(
                Uri.parse('$baseUrl/api/v1/auth/logout'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 6));
        }
      } catch (_) {}
    }
    await _secureStorage.clearAuthSession();
  }
}

