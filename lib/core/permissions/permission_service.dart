import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Centralized runtime permission manager for Android (API 29-34+) and iOS.
///
/// Handles:
/// - Android 13+ granular media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`)
/// - Android 12 and below (`READ_EXTERNAL_STORAGE`)
/// - Optional full storage access (`MANAGE_EXTERNAL_STORAGE`) for browsing non-media folders
/// - iOS Photo Library permissions via `PhotoManager`
class PermissionService {
  PermissionService._();

  static Future<bool> requestMediaAndStoragePermissions() async {
    try {
      if (Platform.isIOS) {
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        return ps.isAuth || ps.hasAccess;
      }

      if (Platform.isAndroid) {
        // Request Android 13+ granular media permissions along with legacy storage fallback
        final statuses = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.storage,
        ].request();

        final hasMedia = (statuses[Permission.photos]?.isGranted ?? false) ||
            (statuses[Permission.videos]?.isGranted ?? false) ||
            (statuses[Permission.storage]?.isGranted ?? false);

        return hasMedia;
      }
      return true;
    } catch (_) {
      // Fallback for desktop/web preview environments
      return true;
    }
  }

  /// Requests `MANAGE_EXTERNAL_STORAGE` on Android 11+ when the user wants full
  /// folder browsing in Internal Storage outside standard MediaStore collections.
  static Future<bool> requestFullFileAccessIfNeeded() async {
    try {
      if (!Platform.isAndroid) return true;
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return true;
      final result = await Permission.manageExternalStorage.request();
      return result.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSystemPermissionSettings() async {
    await openAppSettings();
  }
}

