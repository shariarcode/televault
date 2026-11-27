# TeleVault — Personal File Manager & Telegram Cloud Drive

**TeleVault** is a modular Flutter mobile application (Android & iOS) for personal file, photo, and storage management paired with private backup to a user's own Telegram account (`Saved Messages` or dedicated private channel) via a configurable MTProto client bridge.

---

## 1. Architecture & Modular Folder Structure

```text
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # Storage thresholds, default folders, env keys
│   ├── database/
│   │   └── local_database.dart        # SQLite (sqflite) for indexing, SHA-256 dedup, upload queue & recycle bin
│   ├── models/
│   │   └── vault_models.dart          # Immutable models for files, folders, queue tasks, duplicates, auth
│   ├── network/
│   │   └── telegram_bridge_client.dart # Configurable HTTP/MTProto bridge client (Phone -> OTP -> 2FA -> Upload)
│   ├── permissions/
│   │   └── permission_service.dart    # Android 13+ granular media & storage permissions + iOS Photos access
│   ├── storage/
│   │   └── secure_storage_service.dart # Hardware-backed Keystore/Keychain wrapper for session tokens & bridge URL
│   └── theme/
│       └── app_theme.dart             # Warm Alabaster + Deep Obsidian + Electric Indigo/Cyan design system
├── shared/
│   └── widgets/
│       ├── app_shell.dart             # 5-tab floating dock navigation (Home, Files, Cloud Hub, Search, Tools)
│       ├── status_badge.dart          # High-contrast pill badges & category chips
│       └── vault_cards.dart           # Dark feature hero card, section groups, progress bars, safety banners
└── features/
    ├── auth_otp/
    │   ├── providers/
    │   │   └── auth_provider.dart     # State machine: Unauthenticated -> AwaitingOTP -> Awaiting2FA -> Connected
    │   └── presentation/
    │       └── telegram_auth_sheet.dart # Step-by-step Phone + Country Code -> OTP timer -> 2FA modal flow
    ├── home/
    │   └── presentation/
    │       └── home_screen.dart       # Dynamic greeting, quick search, Telegram Cloud hero card, Library, Device stats
    ├── files/
    │   ├── providers/
    │   │   └── files_provider.dart    # Device folder & file scanner, sort, multi-select, starred & recycle bin logic
    │   └── presentation/
    │       └── files_screen.dart      # Internal Storage browser, list/grid toggle, breadcrumb drill-down, batch upload
    ├── telegram_cloud/
    │   ├── providers/
    │   │   └── cloud_sync_provider.dart # Upload queue processor, SHA-256 duplicate prevention, Wi-Fi auto-backup rules
    │   └── presentation/
    │       └── telegram_cloud_screen.dart # Cloud onboarding / connected hub, sync rules, live upload queue & history
    ├── search/
    │   └── presentation/
    │       └── search_screen.dart     # Real-time global search with horizontal category filter pills (All, Images, etc.)
    └── tools/
        └── presentation/
            └── tools_screen.dart      # Storage Analyzer, Large Files (>50MB), SHA-256 Duplicates, Recycle Bin, Compress/Extract
```

---

## 2. Getting Started & Configuration

### Prerequisites
- Flutter SDK `>=3.2.0 <4.0.0`
- Android Studio / Xcode for mobile builds

### Installation
1. Clone the repository and copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Install packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

### Configurable MTProto Bridge Backend
Telegram's official **Bot API** cannot authenticate using a personal user phone number + OTP and has a 50 MB / 2 GB file limit depending on hosting. To use a user's personal Telegram account (`Saved Messages`) with phone number login and up to 2 GB (or 4 GB Premium) per file:
- **Never embed `api_id` or `api_hash` in the Flutter APK/IPA**, as mobile binaries can be decompiled.
- Host a lightweight stateless or encrypted-session MTProto bridge (using **Telethon**, **Pyrogram**, **GramJS**, or **TDLib**) and configure its endpoint in `.env` (`TELEVAULT_BRIDGE_URL`) or inside the app's **Bridge Settings** dialog.
- **Expected Bridge Endpoints:**
  - `POST /api/v1/auth/send-code` — Accepts `{ "phoneNumber": "+88017..." }`, returns `{ "phoneCodeHash": "...", "timeoutSeconds": 60 }`.
  - `POST /api/v1/auth/verify-otp` — Accepts `{ "phoneNumber": "...", "code": "12345", "phoneCodeHash": "..." }`, returns `{ "status": "authenticated", "sessionToken": "..." }` or `{ "status": "2fa_required" }`.
  - `POST /api/v1/auth/verify-2fa` — Accepts `{ "password": "...", "phoneCodeHash": "..." }`, returns `{ "status": "authenticated", "sessionToken": "..." }`.
  - `POST /api/v1/files/upload` — Multipart upload with `Authorization: Bearer <sessionToken>`, `sha256`, `folderName`, and file stream.
  - `POST /api/v1/auth/logout` — Terminates the MTProto session cleanly.
- **Built-in Demo/Simulation Mode:** By default, `TELEVAULT_DEMO_MODE=true` allows full interactive testing of the Phone -> OTP -> 2FA -> SHA-256 Deduplication -> Upload Queue flow offline without a live server.

---

## 3. Platform Permissions (Android & iOS)

### Android (`android/app/src/main/AndroidManifest.xml`)
Add the following permissions inside `<manifest>`:
```xml
<!-- Network & Wi-Fi state for auto-backup rules -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Android 13+ (API 33+) Granular Media Permissions -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- Android 12 and below (API <= 32) Legacy Storage -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />

<!-- Optional: Full File Manager access for browsing non-media folders (Documents, Android, Fonts, etc.) -->
<!-- Note: Google Play requires a Permissions Declaration Form if publishing with MANAGE_EXTERNAL_STORAGE -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

<!-- Optional: Query installed packages for the Tools -> Apps utility -->
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

### iOS (`ios/Runner/Info.plist`)
Add the following keys inside `<dict>`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>TeleVault needs access to your Photo Library to organize photos, detect duplicates, and back up selected albums to your Telegram Cloud.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>TeleVault needs permission to save restored or extracted files to your library.</string>
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

---

## 4. Android & iOS Background Execution Limits

- **Android Scoped Storage & WorkManager:**
  - Android 11+ enforces Scoped Storage. Media files (`DCIM`, `Pictures`, `Movies`, `Music`) are accessible via `MediaStore` (`photo_manager`), while arbitrary folders (`Documents`, `Download`) use SAF (`file_picker`) or `MANAGE_EXTERNAL_STORAGE` on dedicated file manager builds.
  - Long-running uploads while the app is minimized are throttled by Android Doze Mode unless run inside a **Foreground Service** with a persistent notification or scheduled via `WorkManager` with `NetworkType.UNMETERED` (Wi-Fi only).
- **iOS Background App Refresh (`BGProcessingTask`):**
  - iOS strictly suspends background sockets after ~30 seconds. Continuous large video uploads require `URLSessionConfiguration.background` or `BGProcessingTaskRequest` (which runs primarily when the iPhone is connected to power and Wi-Fi).
  - TeleVault persists every queue item and its SHA-256 digest in SQLite so interrupted uploads safely resume when the app returns to the foreground.

---

## 5. Security & Privacy Best Practices

1. **Enable Telegram Two-Step Verification (2FA):** Users should always enable a Cloud Password in Telegram (`Settings -> Privacy and Security -> Two-Step Verification`) so an intercepted SMS OTP alone cannot compromise their cloud files.
2. **Avoid Uploading Sensitive Identity Documents Unencrypted:** Do **not** store raw National IDs (NIDs), passports, tax documents, seed phrases, or banking credentials in standard Telegram Cloud chats (`Saved Messages`). Standard Telegram Cloud chats use server-client encryption rather than end-to-end encryption.
3. **Hardware-Backed Token Storage:** Session tokens and bridge credentials are encrypted at rest via `flutter_secure_storage` (Android EncryptedSharedPreferences/Keystore and iOS Keychain with `unlocked_this_device`).
4. **SHA-256 Deduplication:** Files are hashed locally in chunks before uploading. If a file's SHA-256 hash is already recorded as `uploaded` in the local SQLite database, TeleVault skips re-uploading it automatically.

