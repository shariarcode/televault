import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/telegram_bridge_client.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Authentication Step State Machine:
/// 1. `phoneInput`: Country code + phone number entry
/// 2. `otpInput`: 5-digit OTP verification with resend countdown timer
/// 3. `twoFactorInput`: Optional Telegram Two-Step Verification Cloud Password
/// 4. `authenticated`: Connected session stored in hardware-backed secure storage
enum AuthFlowStep {
  phoneInput,
  otpInput,
  twoFactorInput,
  authenticated,
}

class AuthState {
  final AuthFlowStep step;
  final String countryCode;
  final String phoneNumber;
  final String? phoneCodeHash;
  final String? connectedPhone;
  final String? connectedUsername;
  final String bridgeUrl;
  final bool isDemoMode;
  final bool isLoading;
  final int resendSecondsRemaining;
  final String? errorMessage;

  const AuthState({
    this.step = AuthFlowStep.phoneInput,
    this.countryCode = '+880',
    this.phoneNumber = '',
    this.phoneCodeHash,
    this.connectedPhone,
    this.connectedUsername,
    this.bridgeUrl = 'http://localhost:8765',
    this.isDemoMode = false,
    this.isLoading = false,
    this.resendSecondsRemaining = 0,
    this.errorMessage,
  });

  bool get isConnected =>
      step == AuthFlowStep.authenticated && connectedPhone != null;

  AuthState copyWith({
    AuthFlowStep? step,
    String? countryCode,
    String? phoneNumber,
    String? phoneCodeHash,
    String? connectedPhone,
    String? connectedUsername,
    String? bridgeUrl,
    bool? isDemoMode,
    bool? isLoading,
    int? resendSecondsRemaining,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      step: step ?? this.step,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCodeHash: phoneCodeHash ?? this.phoneCodeHash,
      connectedPhone: connectedPhone ?? this.connectedPhone,
      connectedUsername: connectedUsername ?? this.connectedUsername,
      bridgeUrl: bridgeUrl ?? this.bridgeUrl,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      isLoading: isLoading ?? this.isLoading,
      resendSecondsRemaining:
          resendSecondsRemaining ?? this.resendSecondsRemaining,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final telegramBridgeProvider = Provider<TelegramBridgeClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return TelegramBridgeClient(secureStorage: storage);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService _storage;
  final TelegramBridgeClient _bridge;
  Timer? _resendTimer;

  AuthNotifier({
    required SecureStorageService storage,
    required TelegramBridgeClient bridge,
  })  : _storage = storage,
        _bridge = bridge,
        super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _storage.getSessionToken();
    final phone = await _storage.getConnectedPhone();
    final username = await _storage.getConnectedUsername();
    final bridgeUrl = await _storage.getBridgeUrl();
    final demoMode = await _storage.getDemoMode();

    if (token != null && token.isNotEmpty && phone != null) {
      state = state.copyWith(
        step: AuthFlowStep.authenticated,
        connectedPhone: phone,
        connectedUsername: username ?? 'Saved Messages ($phone)',
        bridgeUrl: bridgeUrl ?? state.bridgeUrl,
        isDemoMode: demoMode,
      );
    } else {
      state = state.copyWith(
        bridgeUrl: bridgeUrl ?? state.bridgeUrl,
        isDemoMode: demoMode,
      );
    }
  }

  void setCountryCode(String code) {
    state = state.copyWith(countryCode: code, clearError: true);
  }

  Future<void> updateBridgeConfig({
    required String bridgeUrl,
    required bool isDemoMode,
  }) async {
    await _storage.setBridgeUrl(bridgeUrl);
    await _storage.setDemoMode(isDemoMode);
    state = state.copyWith(
      bridgeUrl: bridgeUrl.trim(),
      isDemoMode: isDemoMode,
      clearError: true,
    );
  }

  /// Step 1: Request OTP code for the entered country code + phone number.
  Future<bool> sendOtpCode(String rawPhone) async {
    final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 6) {
      state = state.copyWith(
        errorMessage: 'Please enter a valid mobile number.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      phoneNumber: cleaned,
      clearError: true,
    );

    final result = await _bridge.requestOtpCode(
      countryCode: state.countryCode,
      phoneNumber: cleaned,
    );

    if (result.success) {
      _startResendTimer(60);
      state = state.copyWith(
        isLoading: false,
        step: AuthFlowStep.otpInput,
        phoneCodeHash: result.phoneCodeHash,
        clearError: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Could not send OTP code.',
      );
      return false;
    }
  }

  /// Step 2: Verify the 5-digit OTP code.
  Future<bool> verifyOtpCode(String otpCode) async {
    final fullPhone = '${state.countryCode}${state.phoneNumber}';
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _bridge.verifyOtpCode(
      fullPhone: fullPhone,
      otpCode: otpCode,
      phoneCodeHash: state.phoneCodeHash ?? 'demo_hash',
    );

    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Invalid OTP code.',
      );
      return false;
    }

    if (result.requires2FA) {
      state = state.copyWith(
        isLoading: false,
        step: AuthFlowStep.twoFactorInput,
        clearError: true,
      );
      return true;
    }

    final token = result.sessionToken ?? 'tv_token';
    final username = result.username ?? 'Saved Messages ($fullPhone)';
    await _storage.saveAuthSession(
      sessionToken: token,
      phoneNumber: fullPhone,
      username: username,
    );

    _resendTimer?.cancel();
    state = state.copyWith(
      isLoading: false,
      step: AuthFlowStep.authenticated,
      connectedPhone: fullPhone,
      connectedUsername: username,
      clearError: true,
    );
    return true;
  }

  /// Step 2b: Verify Two-Step Verification (Cloud Password).
  Future<bool> verifyTwoFactorPassword(String password) async {
    final fullPhone = '${state.countryCode}${state.phoneNumber}';
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _bridge.verifyTwoFactorPassword(
      fullPhone: fullPhone,
      password: password,
      phoneCodeHash: state.phoneCodeHash ?? 'demo_hash',
    );

    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Invalid 2FA password.',
      );
      return false;
    }

    final token = result.sessionToken ?? 'tv_2fa_token';
    final username = result.username ?? 'Saved Messages ($fullPhone)';
    await _storage.saveAuthSession(
      sessionToken: token,
      phoneNumber: fullPhone,
      username: username,
    );

    _resendTimer?.cancel();
    state = state.copyWith(
      isLoading: false,
      step: AuthFlowStep.authenticated,
      connectedPhone: fullPhone,
      connectedUsername: username,
      clearError: true,
    );
    return true;
  }

  void backToPhoneInput() {
    _resendTimer?.cancel();
    state = state.copyWith(
      step: AuthFlowStep.phoneInput,
      clearError: true,
    );
  }

  /// Step 3: Safe Disconnect & Logout.
  Future<void> disconnectTelegram() async {
    state = state.copyWith(isLoading: true);
    await _bridge.logoutSession();
    _resendTimer?.cancel();
    state = AuthState(
      step: AuthFlowStep.phoneInput,
      countryCode: state.countryCode,
      bridgeUrl: state.bridgeUrl,
      isDemoMode: state.isDemoMode,
    );
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    state = state.copyWith(resendSecondsRemaining: seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendSecondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(resendSecondsRemaining: 0);
      } else {
        state = state.copyWith(
          resendSecondsRemaining: state.resendSecondsRemaining - 1,
        );
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    storage: ref.watch(secureStorageProvider),
    bridge: ref.watch(telegramBridgeProvider),
  );
});

