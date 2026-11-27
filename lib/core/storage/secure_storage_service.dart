import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Hardware-backed secure storage wrapper for Telegram session tokens,
/// connected phone metadata, bridge endpoint URLs, and auto-backup preferences.
///
/// Never stores raw `api_id` or `api_hash` in plain text.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<void> saveAuthSession({
    required String sessionToken,
    required String phoneNumber,
    required String username,
  }) async {
    await _storage.write(key: AppConstants.keySessionToken, value: sessionToken);
    await _storage.write(key: AppConstants.keyConnectedPhone, value: phoneNumber);
    await _storage.write(key: AppConstants.keyConnectedUsername, value: username);
  }

  Future<String?> getSessionToken() =>
      _storage.read(key: AppConstants.keySessionToken);

  Future<String?> getConnectedPhone() =>
      _storage.read(key: AppConstants.keyConnectedPhone);

  Future<String?> getConnectedUsername() =>
      _storage.read(key: AppConstants.keyConnectedUsername);

  Future<void> clearAuthSession() async {
    await _storage.delete(key: AppConstants.keySessionToken);
    await _storage.delete(key: AppConstants.keyConnectedPhone);
    await _storage.delete(key: AppConstants.keyConnectedUsername);
  }

  Future<void> setBridgeUrl(String url) =>
      _storage.write(key: AppConstants.keyBridgeUrl, value: url.trim());

  Future<String?> getBridgeUrl() =>
      _storage.read(key: AppConstants.keyBridgeUrl);

  Future<void> setDemoMode(bool enabled) =>
      _storage.write(key: AppConstants.keyDemoMode, value: enabled.toString());

  Future<bool> getDemoMode({bool defaultValue = true}) async {
    final val = await _storage.read(key: AppConstants.keyDemoMode);
    if (val == null) return defaultValue;
    return val.toLowerCase() == 'true';
  }

  Future<void> saveAutoBackupSettings({
    required bool autoBackup,
    required bool wifiOnly,
    required bool skipDuplicates,
    required List<String> selectedAlbums,
  }) async {
    await _storage.write(
        key: AppConstants.keyAutoBackupEnabled, value: autoBackup.toString());
    await _storage.write(
        key: AppConstants.keyWifiOnlyEnabled, value: wifiOnly.toString());
    await _storage.write(
        key: AppConstants.keySkipDuplicatesEnabled,
        value: skipDuplicates.toString());
    await _storage.write(
        key: AppConstants.keySelectedAlbums, value: selectedAlbums.join(','));
  }

  Future<Map<String, dynamic>> loadAutoBackupSettings() async {
    final autoBackup =
        await _storage.read(key: AppConstants.keyAutoBackupEnabled);
    final wifiOnly = await _storage.read(key: AppConstants.keyWifiOnlyEnabled);
    final skipDuplicates =
        await _storage.read(key: AppConstants.keySkipDuplicatesEnabled);
    final albumsRaw =
        await _storage.read(key: AppConstants.keySelectedAlbums);

    return {
      'autoBackup': autoBackup == null ? false : autoBackup == 'true',
      'wifiOnly': wifiOnly == null ? true : wifiOnly == 'true',
      'skipDuplicates':
          skipDuplicates == null ? true : skipDuplicates == 'true',
      'selectedAlbums': (albumsRaw == null || albumsRaw.isEmpty)
          ? <String>['DCIM', 'Pictures', 'Documents']
          : albumsRaw.split(','),
    };
  }
}

