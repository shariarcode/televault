import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/local_database.dart';
import '../../../core/models/vault_models.dart';
import '../../../core/network/telegram_bridge_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth_otp/providers/auth_provider.dart';
import '../../files/providers/files_provider.dart';

class CloudSyncState {
  final bool autoBackupEnabled;
  final bool wifiOnly;
  final bool skipDuplicates;
  final List<String> selectedAlbums;
  final List<UploadQueueItem> queue;
  final bool isUploading;
  final bool isQueuePaused;
  final String? lastSyncMessage;

  const CloudSyncState({
    this.autoBackupEnabled = false,
    this.wifiOnly = true,
    this.skipDuplicates = true,
    this.selectedAlbums = const ['DCIM', 'Pictures', 'Documents'],
    this.queue = const [],
    this.isUploading = false,
    this.isQueuePaused = false,
    this.lastSyncMessage,
  });

  int get pendingCount => queue
      .where((e) =>
          e.status == UploadTaskStatus.pending ||
          e.status == UploadTaskStatus.uploading)
      .length;

  int get uploadedCount =>
      queue.where((e) => e.status == UploadTaskStatus.uploaded).length;

  int get skippedDuplicatesCount =>
      queue.where((e) => e.status == UploadTaskStatus.skippedDuplicate).length;

  double get overallProgress {
    if (queue.isEmpty) return 0.0;
    final total = queue.fold<double>(0.0, (sum, item) {
      if (item.status == UploadTaskStatus.uploaded ||
          item.status == UploadTaskStatus.skippedDuplicate) {
        return sum + 1.0;
      }
      return sum + item.progress;
    });
    return (total / queue.length).clamp(0.0, 1.0);
  }

  CloudSyncState copyWith({
    bool? autoBackupEnabled,
    bool? wifiOnly,
    bool? skipDuplicates,
    List<String>? selectedAlbums,
    List<UploadQueueItem>? queue,
    bool? isUploading,
    bool? isQueuePaused,
    String? lastSyncMessage,
  }) {
    return CloudSyncState(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      skipDuplicates: skipDuplicates ?? this.skipDuplicates,
      selectedAlbums: selectedAlbums ?? this.selectedAlbums,
      queue: queue ?? this.queue,
      isUploading: isUploading ?? this.isUploading,
      isQueuePaused: isQueuePaused ?? this.isQueuePaused,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
    );
  }
}

class CloudSyncNotifier extends StateNotifier<CloudSyncState> {
  final SecureStorageService _storage;
  final TelegramBridgeClient _bridge;
  final Ref _ref;
  final _uuid = const Uuid();
  bool _processingLoop = false;

  CloudSyncNotifier({
    required SecureStorageService storage,
    required TelegramBridgeClient bridge,
    required Ref ref,
  })  : _storage = storage,
        _bridge = bridge,
        _ref = ref,
        super(const CloudSyncState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final settings = await _storage.loadAutoBackupSettings();
    final savedQueue = await LocalDatabase.instance.getUploadQueue();
    state = state.copyWith(
      autoBackupEnabled: settings['autoBackup'] as bool,
      wifiOnly: settings['wifiOnly'] as bool,
      skipDuplicates: settings['skipDuplicates'] as bool,
      selectedAlbums: settings['selectedAlbums'] as List<String>,
      queue: savedQueue,
    );
  }

  Future<void> _persistSettings() async {
    await _storage.saveAutoBackupSettings(
      autoBackup: state.autoBackupEnabled,
      wifiOnly: state.wifiOnly,
      skipDuplicates: state.skipDuplicates,
      selectedAlbums: state.selectedAlbums,
    );
  }

  Future<void> toggleAutoBackup(bool value) async {
    state = state.copyWith(autoBackupEnabled: value);
    await _persistSettings();
    if (value) {
      await syncSelectedFoldersNow();
    }
  }

  Future<void> toggleWifiOnly(bool value) async {
    state = state.copyWith(wifiOnly: value);
    await _persistSettings();
  }

  Future<void> toggleSkipDuplicates(bool value) async {
    state = state.copyWith(skipDuplicates: value);
    await _persistSettings();
  }

  Future<void> toggleAlbumSelection(String folderName) async {
    final updated = List<String>.from(state.selectedAlbums);
    if (updated.contains(folderName)) {
      updated.remove(folderName);
    } else {
      updated.add(folderName);
    }
    state = state.copyWith(selectedAlbums: updated);
    await _persistSettings();
  }

  /// Enqueues a list of files for upload to Telegram Cloud with SHA-256 duplicate prevention.
  Future<int> enqueueFiles(List<VaultFileItem> files) async {
    int addedCount = 0;

    for (final file in files) {
      final hash = file.sha256Hash ??
          await TelegramBridgeClient.computeFileSha256(
            filePath: file.path,
            fileName: file.name,
            sizeBytes: file.sizeBytes,
          );

      // Check if already in active queue
      final alreadyQueued = state.queue.any((q) =>
          q.sha256Hash == hash &&
          (q.status == UploadTaskStatus.pending ||
              q.status == UploadTaskStatus.uploading));
      if (alreadyQueued) continue;

      // SHA-256 Duplicate Prevention check
      if (state.skipDuplicates) {
        final alreadyBackedUp =
            await LocalDatabase.instance.isHashAlreadyBackedUp(hash);
        if (alreadyBackedUp || file.isBackedUp) {
          final skippedTask = UploadQueueItem(
            id: _uuid.v4(),
            fileId: file.id,
            fileName: file.name,
            filePath: file.path,
            folderName: file.folderName,
            sizeBytes: file.sizeBytes,
            sha256Hash: hash,
            status: UploadTaskStatus.skippedDuplicate,
            progress: 1.0,
            updatedAt: DateTime.now(),
          );
          await LocalDatabase.instance.upsertQueueItem(skippedTask);
          continue;
        }
      }

      final task = UploadQueueItem(
        id: _uuid.v4(),
        fileId: file.id,
        fileName: file.name,
        filePath: file.path,
        folderName: file.folderName,
        sizeBytes: file.sizeBytes,
        sha256Hash: hash,
        status: UploadTaskStatus.pending,
        progress: 0.0,
        updatedAt: DateTime.now(),
      );
      await LocalDatabase.instance.upsertQueueItem(task);
      addedCount++;
    }

    final refreshedQueue = await LocalDatabase.instance.getUploadQueue();
    state = state.copyWith(
      queue: refreshedQueue,
      lastSyncMessage: addedCount > 0
          ? 'Queued $addedCount file(s) for Telegram Cloud backup.'
          : 'All selected files were already backed up (SHA-256 verified).',
    );

    _processQueueLoop();
    return addedCount;
  }

  /// "Sync Now" trigger: scans files inside all selected auto-backup albums/folders
  /// and queues any unbacked-up files.
  Future<void> syncSelectedFoldersNow() async {
    final allFiles = _ref.read(filesProvider).allFiles;
    final matching = allFiles
        .where((f) =>
            !f.isDeleted && state.selectedAlbums.contains(f.folderName))
        .toList();

    if (matching.isEmpty) {
      state = state.copyWith(
        lastSyncMessage: 'No files found in selected auto-backup folders.',
      );
      return;
    }
    await enqueueFiles(matching);
  }

  Future<bool> _checkWifiAllowed() async {
    if (!state.wifiOnly) return true;
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet) ||
          results.contains(ConnectivityResult.none)) {
        // Note: ConnectivityResult.none is permitted in offline simulation mode
        return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _processQueueLoop() async {
    if (_processingLoop || state.isQueuePaused) return;
    _processingLoop = true;
    state = state.copyWith(isUploading: true);

    try {
      while (!state.isQueuePaused) {
        final pendingList = state.queue
            .where((q) => q.status == UploadTaskStatus.pending)
            .toList();
        if (pendingList.isEmpty) break;

        final wifiOk = await _checkWifiAllowed();
        if (!wifiOk) {
          state = state.copyWith(
            isQueuePaused: true,
            lastSyncMessage:
                'Paused: Waiting for Wi-Fi connection (Wi-Fi only rule enabled).',
          );
          break;
        }

        final currentTask = pendingList.last; // FIFO order
        await _updateTaskInState(
          currentTask.copyWith(
            status: UploadTaskStatus.uploading,
            progress: 0.05,
            updatedAt: DateTime.now(),
          ),
        );

        try {
          final msgId = await _bridge.uploadFileToTelegram(
            filePath: currentTask.filePath,
            fileName: currentTask.fileName,
            folderName: currentTask.folderName,
            sizeBytes: currentTask.sizeBytes,
            sha256Hash: currentTask.sha256Hash,
            isCancelledOrPaused: () => state.isQueuePaused,
            onProgress: (p) {
              _updateTaskInState(
                currentTask.copyWith(
                  status: UploadTaskStatus.uploading,
                  progress: p,
                  updatedAt: DateTime.now(),
                ),
              );
            },
          );

          await LocalDatabase.instance.markFileBackedUp(
            currentTask.fileId,
            currentTask.sha256Hash,
          );

          await _updateTaskInState(
            currentTask.copyWith(
              status: UploadTaskStatus.uploaded,
              progress: 1.0,
              telegramMessageId: msgId,
              updatedAt: DateTime.now(),
            ),
          );

          await _ref.read(filesProvider.notifier).refreshFiles();
        } catch (e) {
          final newStatus = state.isQueuePaused
              ? UploadTaskStatus.paused
              : UploadTaskStatus.failed;
          await _updateTaskInState(
            currentTask.copyWith(
              status: newStatus,
              errorMessage: e.toString(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    } finally {
      _processingLoop = false;
      state = state.copyWith(isUploading: false);
    }
  }

  Future<void> _updateTaskInState(UploadQueueItem updated) async {
    await LocalDatabase.instance.upsertQueueItem(updated);
    final newList = state.queue.map((item) {
      return item.id == updated.id ? updated : item;
    }).toList();
    state = state.copyWith(queue: newList);
  }

  Future<void> pauseQueue() async {
    state = state.copyWith(
      isQueuePaused: true,
      lastSyncMessage: 'Upload queue paused.',
    );
  }

  Future<void> resumeQueue() async {
    for (final item in state.queue) {
      if (item.status == UploadTaskStatus.paused ||
          item.status == UploadTaskStatus.failed) {
        await LocalDatabase.instance.upsertQueueItem(
          item.copyWith(
            status: UploadTaskStatus.pending,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    final refreshed = await LocalDatabase.instance.getUploadQueue();
    state = state.copyWith(
      isQueuePaused: false,
      queue: refreshed,
      lastSyncMessage: 'Resumed Telegram Cloud upload queue.',
    );
    _processQueueLoop();
  }

  Future<void> cancelTask(String taskId) async {
    await LocalDatabase.instance.removeQueueItem(taskId);
    final refreshed = await LocalDatabase.instance.getUploadQueue();
    state = state.copyWith(queue: refreshed);
  }

  Future<void> clearCompletedHistory() async {
    await LocalDatabase.instance.clearCompletedQueueItems();
    final refreshed = await LocalDatabase.instance.getUploadQueue();
    state = state.copyWith(
      queue: refreshed,
      lastSyncMessage: 'Cleared completed upload history.',
    );
  }
}

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncNotifier, CloudSyncState>((ref) {
  return CloudSyncNotifier(
    storage: ref.watch(secureStorageProvider),
    bridge: ref.watch(telegramBridgeProvider),
    ref: ref,
  );
});

