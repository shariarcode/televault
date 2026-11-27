class AppConstants {
  AppConstants._();

  static const String appName = 'TeleVault';
  static const String appTagline = 'Your Telegram, now a cloud drive.';

  // Storage thresholds
  static const int largeFileThresholdBytes = 50 * 1024 * 1024; // 50 MB
  static const int simulatedTotalStorageBytes = 224 * 1024 * 1024 * 1024; // 224 GB
  static const int simulatedUsedStorageBytes = 90 * 1024 * 1024 * 1024; // 90.0 GB

  // Secure Storage Keys
  static const String keySessionToken = 'televault_session_token';
  static const String keyConnectedPhone = 'televault_connected_phone';
  static const String keyConnectedUsername = 'televault_connected_username';
  static const String keyBridgeUrl = 'televault_bridge_url';
  static const String keyDemoMode = 'televault_demo_mode';
  static const String keyAutoBackupEnabled = 'televault_auto_backup_enabled';
  static const String keyWifiOnlyEnabled = 'televault_wifi_only_enabled';
  static const String keySkipDuplicatesEnabled = 'televault_skip_duplicates_enabled';
  static const String keySelectedAlbums = 'televault_selected_albums';

  // Default Internal Storage Folders (matching reference Android file hierarchy)
  static const List<String> defaultInternalFolders = [
    'Android',
    'DCIM',
    'Documents',
    'Download',
    'Fonts',
    'MIUI',
    'Movies',
    'Music',
    'MxPlayerAd',
    'Notifications',
    'Pictures',
  ];

  // Safety Notice
  static const String securityWarningTitle = 'Security & Privacy Notice';
  static const String securityWarningBody =
      '1. Always enable Telegram Two-Step Verification (Cloud Password) in your Telegram settings.\n'
      '2. Avoid storing sensitive identity documents (such as NIDs, passports, or banking info) in unencrypted cloud chats.';
}

