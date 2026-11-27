import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/vault_models.dart';

/// SQLite Local Database for TeleVault.
///
/// Tracks:
/// 1. `vault_files`: Device & cloud file index, SHA-256 hash, starred status, recycle bin state.
/// 2. `upload_queue`: Active, completed, and failed Telegram upload tasks with SHA-256 deduplication.
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();

  Database? _db;
  final List<VaultFileItem> _memoryFilesFallback = [];
  final List<UploadQueueItem> _memoryQueueFallback = [];
  bool _seeded = false;

  Future<Database?> get database async {
    if (_db != null) return _db;
    try {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'televault_index.db');
      _db = await openDatabase(
        fullPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE vault_files (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              path TEXT NOT NULL,
              folder_name TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              modified_at INTEGER NOT NULL,
              category TEXT NOT NULL,
              sha256_hash TEXT,
              is_starred INTEGER DEFAULT 0,
              is_backed_up INTEGER DEFAULT 0,
              is_hidden INTEGER DEFAULT 0,
              is_deleted INTEGER DEFAULT 0,
              deleted_at INTEGER,
              people_group TEXT
            )
          ''');

          await db.execute('''
            CREATE INDEX idx_vault_files_sha256 ON vault_files(sha256_hash)
          ''');

          await db.execute('''
            CREATE TABLE upload_queue (
              id TEXT PRIMARY KEY,
              file_id TEXT NOT NULL,
              file_name TEXT NOT NULL,
              file_path TEXT NOT NULL,
              folder_name TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              sha256_hash TEXT NOT NULL,
              status TEXT NOT NULL,
              progress REAL DEFAULT 0.0,
              telegram_message_id TEXT,
              error_message TEXT,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      );
      return _db;
    } catch (_) {
      // Fallback to in-memory store if running in an environment without SQLite binary
      return null;
    }
  }

  /// Seeds realistic initial device files & folders so Internal Storage, Large Files (>50MB),
  /// SHA-256 Duplicates, Hidden Files, and Library views work out-of-the-box and merge cleanly
  /// with real device files.
  Future<void> ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;

    final existing = await getAllFiles(includeDeleted: true);
    if (existing.isNotEmpty) return;

    final seedItems = <VaultFileItem>[
      // Large files (>50 MB)
      VaultFileItem(
        id: 'file_vid_4k_01',
        name: 'CoxsBazar_Sunset_4K_60fps.mp4',
        path: '/storage/emulated/0/DCIM/Camera/CoxsBazar_Sunset_4K_60fps.mp4',
        folderName: 'DCIM',
        sizeBytes: 342 * 1024 * 1024, // 342 MB
        modifiedAt: DateTime(2026, 11, 25, 17, 40),
        category: FileCategory.videos,
        sha256Hash: 'a94f8e12c3b40192d8f7e65a112233445566778899aabbccddeeff0011223344',
        isStarred: true,
        peopleGroup: 'Family & Trips',
      ),
      VaultFileItem(
        id: 'file_vid_4k_02',
        name: 'Birthday_Dinner_Reel_HDR.mov',
        path: '/storage/emulated/0/Movies/Birthday_Dinner_Reel_HDR.mov',
        folderName: 'Movies',
        sizeBytes: 185 * 1024 * 1024, // 185 MB
        modifiedAt: DateTime(2026, 11, 3, 21, 15),
        category: FileCategory.videos,
        sha256Hash: 'b83e7d11c2a30192d8f7e65a112233445566778899aabbccddeeff0099887766',
        peopleGroup: 'Friends',
      ),
      VaultFileItem(
        id: 'file_zip_backup_01',
        name: 'Studio_RAW_Photos_Archive_2026.zip',
        path: '/storage/emulated/0/Download/Studio_RAW_Photos_Archive_2026.zip',
        folderName: 'Download',
        sizeBytes: 128 * 1024 * 1024, // 128 MB
        modifiedAt: DateTime(2026, 11, 26, 14, 10),
        category: FileCategory.docs,
        sha256Hash: 'c72d6c00b1920192d8f7e65a112233445566778899aabbccddeeff1122334455',
      ),
      VaultFileItem(
        id: 'file_apk_release_01',
        name: 'TeleVault_Universal_v1.0.0.apk',
        path: '/storage/emulated/0/Download/TeleVault_Universal_v1.0.0.apk',
        folderName: 'Download',
        sizeBytes: 64 * 1024 * 1024, // 64 MB
        modifiedAt: DateTime(2026, 11, 26, 19, 30),
        category: FileCategory.apps,
        sha256Hash: 'd61c5b99a0810192d8f7e65a112233445566778899aabbccddeeff5566778899',
      ),

      // Duplicate Group 1 (Identical SHA-256 across DCIM and Pictures)
      VaultFileItem(
        id: 'file_img_dup_1a',
        name: 'IMG_20261125_Portrait_Studio.jpg',
        path: '/storage/emulated/0/DCIM/IMG_20261125_Portrait_Studio.jpg',
        folderName: 'DCIM',
        sizeBytes: 8450000, // 8.45 MB
        modifiedAt: DateTime(2026, 11, 25, 16, 20),
        category: FileCategory.images,
        sha256Hash: 'dup_hash_99112233445566778899aabbccddeeff00112233445566778899aabb',
        isStarred: true,
        peopleGroup: 'Portraits',
      ),
      VaultFileItem(
        id: 'file_img_dup_1b',
        name: 'IMG_20261125_Portrait_Studio (1).jpg',
        path: '/storage/emulated/0/Pictures/IMG_20261125_Portrait_Studio (1).jpg',
        folderName: 'Pictures',
        sizeBytes: 8450000, // 8.45 MB
        modifiedAt: DateTime(2026, 11, 27, 10, 05),
        category: FileCategory.images,
        sha256Hash: 'dup_hash_99112233445566778899aabbccddeeff00112233445566778899aabb',
        peopleGroup: 'Portraits',
      ),

      // Duplicate Group 2 (Identical PDF Invoice in Download and Documents)
      VaultFileItem(
        id: 'file_doc_dup_2a',
        name: 'Q4_Cloud_Architecture_Spec.pdf',
        path: '/storage/emulated/0/Documents/Q4_Cloud_Architecture_Spec.pdf',
        folderName: 'Documents',
        sizeBytes: 5242880, // 5.0 MB
        modifiedAt: DateTime(2026, 10, 28, 11, 15),
        category: FileCategory.docs,
        sha256Hash: 'dup_hash_pdf_77889900112233445566778899aabbccddeeff00112233445566',
        isStarred: true,
      ),
      VaultFileItem(
        id: 'file_doc_dup_2b',
        name: 'Q4_Cloud_Architecture_Spec_Copy.pdf',
        path: '/storage/emulated/0/Download/Q4_Cloud_Architecture_Spec_Copy.pdf',
        folderName: 'Download',
        sizeBytes: 5242880, // 5.0 MB
        modifiedAt: DateTime(2026, 11, 26, 09, 45),
        category: FileCategory.docs,
        sha256Hash: 'dup_hash_pdf_77889900112233445566778899aabbccddeeff00112233445566',
      ),

      // Music & Audio
      VaultFileItem(
        id: 'file_aud_01',
        name: 'Midnight_LoFi_Session_Master.flac',
        path: '/storage/emulated/0/Music/Midnight_LoFi_Session_Master.flac',
        folderName: 'Music',
        sizeBytes: 38 * 1024 * 1024, // 38 MB
        modifiedAt: DateTime(2026, 7, 16, 18, 00),
        category: FileCategory.audio,
        sha256Hash: 'aud_hash_11223344556677889900aabbccddeeff00112233445566778899aabb',
        isStarred: true,
      ),
      VaultFileItem(
        id: 'file_aud_02',
        name: 'VoiceNote_Product_Roadmap.m4a',
        path: '/storage/emulated/0/Notifications/VoiceNote_Product_Roadmap.m4a',
        folderName: 'Notifications',
        sizeBytes: 4200000, // 4.2 MB
        modifiedAt: DateTime(2026, 11, 14, 12, 30),
        category: FileCategory.audio,
        sha256Hash: 'aud_hash_223344556677889900aabbccddeeff00112233445566778899aabbcc',
      ),

      // Additional Photos, Fonts & Hidden files
      VaultFileItem(
        id: 'file_img_03',
        name: 'UI_Design_Board_TeleVault.png',
        path: '/storage/emulated/0/Pictures/UI_Design_Board_TeleVault.png',
        folderName: 'Pictures',
        sizeBytes: 6150000,
        modifiedAt: DateTime(2026, 11, 27, 15, 10),
        category: FileCategory.images,
        sha256Hash: 'img_hash_3344556677889900aabbccddeeff00112233445566778899aabbccdd',
        peopleGroup: 'Work & Design',
      ),
      VaultFileItem(
        id: 'file_font_01',
        name: 'PlusJakartaSans-ExtraBold.ttf',
        path: '/storage/emulated/0/Fonts/PlusJakartaSans-ExtraBold.ttf',
        folderName: 'Fonts',
        sizeBytes: 412000,
        modifiedAt: DateTime(2026, 11, 25, 09, 00),
        category: FileCategory.docs,
        sha256Hash: 'font_hash_44556677889900aabbccddeeff00112233445566778899aabbccddee',
      ),
      VaultFileItem(
        id: 'file_hidden_01',
        name: '.nomedia_vault_index.json',
        path: '/storage/emulated/0/Android/.nomedia_vault_index.json',
        folderName: 'Android',
        sizeBytes: 128000,
        modifiedAt: DateTime(2026, 7, 16, 08, 00),
        category: FileCategory.docs,
        sha256Hash: 'hidden_hash_556677889900aabbccddeeff00112233445566778899aabbccddeeff',
        isHidden: true,
      ),
      VaultFileItem(
        id: 'file_hidden_02',
        name: '.miui_camera_cache.bin',
        path: '/storage/emulated/0/MIUI/.miui_camera_cache.bin',
        folderName: 'MIUI',
        sizeBytes: 14500000,
        modifiedAt: DateTime(2026, 11, 25, 11, 20),
        category: FileCategory.docs,
        sha256Hash: 'hidden_hash_6677889900aabbccddeeff00112233445566778899aabbccddeeff00',
        isHidden: true,
      ),
      // Pre-populated Recycle Bin item for immediate demonstration
      VaultFileItem(
        id: 'file_recycle_01',
        name: 'Old_Draft_Presentation_v1.pptx',
        path: '/storage/emulated/0/Documents/Old_Draft_Presentation_v1.pptx',
        folderName: 'Documents',
        sizeBytes: 19400000,
        modifiedAt: DateTime(2026, 10, 12, 14, 00),
        category: FileCategory.docs,
        sha256Hash: 'recycle_hash_77889900aabbccddeeff00112233445566778899aabbccddeeff0011',
        isDeleted: true,
        deletedAt: DateTime(2026, 11, 26, 18, 00),
      ),
    ];

    for (final item in seedItems) {
      await upsertFile(item);
    }
  }

  Future<void> upsertFile(VaultFileItem item) async {
    final db = await database;
    if (db != null) {
      await db.insert(
        'vault_files',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      _memoryFilesFallback.removeWhere((e) => e.id == item.id);
      _memoryFilesFallback.add(item);
    }
  }

  Future<List<VaultFileItem>> getAllFiles({bool includeDeleted = false}) async {
    final db = await database;
    if (db != null) {
      final rows = await db.query(
        'vault_files',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'modified_at DESC',
      );
      return rows.map(VaultFileItem.fromMap).toList();
    } else {
      return _memoryFilesFallback
          .where((e) => includeDeleted || !e.isDeleted)
          .toList();
    }
  }

  Future<void> toggleStarred(String fileId, bool isStarred) async {
    final db = await database;
    if (db != null) {
      await db.update(
        'vault_files',
        {'is_starred': isStarred ? 1 : 0},
        where: 'id = ?',
        whereArgs: [fileId],
      );
    } else {
      final idx = _memoryFilesFallback.indexWhere((e) => e.id == fileId);
      if (idx != -1) {
        _memoryFilesFallback[idx] =
            _memoryFilesFallback[idx].copyWith(isStarred: isStarred);
      }
    }
  }

  Future<void> markFileBackedUp(String fileId, String sha256Hash) async {
    final db = await database;
    if (db != null) {
      await db.update(
        'vault_files',
        {'is_backed_up': 1, 'sha256_hash': sha256Hash},
        where: 'id = ? OR sha256_hash = ?',
        whereArgs: [fileId, sha256Hash],
      );
    } else {
      for (var i = 0; i < _memoryFilesFallback.length; i++) {
        if (_memoryFilesFallback[i].id == fileId ||
            _memoryFilesFallback[i].sha256Hash == sha256Hash) {
          _memoryFilesFallback[i] = _memoryFilesFallback[i].copyWith(
            isBackedUp: true,
            sha256Hash: sha256Hash,
          );
        }
      }
    }
  }

  /// Checks if a file with the given SHA-256 hash is already backed up to Telegram Cloud.
  Future<bool> isHashAlreadyBackedUp(String sha256Hash) async {
    if (sha256Hash.isEmpty) return false;
    final db = await database;
    if (db != null) {
      final fileRows = await db.query(
        'vault_files',
        where: 'sha256_hash = ? AND is_backed_up = 1',
        whereArgs: [sha256Hash],
        limit: 1,
      );
      if (fileRows.isNotEmpty) return true;

      final queueRows = await db.query(
        'upload_queue',
        where: 'sha256_hash = ? AND status = ?',
        whereArgs: [sha256Hash, UploadTaskStatus.uploaded.name],
        limit: 1,
      );
      return queueRows.isNotEmpty;
    } else {
      return _memoryFilesFallback
              .any((e) => e.sha256Hash == sha256Hash && e.isBackedUp) ||
          _memoryQueueFallback.any((q) =>
              q.sha256Hash == sha256Hash &&
              q.status == UploadTaskStatus.uploaded);
    }
  }

  Future<void> moveToRecycleBin(String fileId) async {
    final now = DateTime.now();
    final db = await database;
    if (db != null) {
      await db.update(
        'vault_files',
        {'is_deleted': 1, 'deleted_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [fileId],
      );
    } else {
      final idx = _memoryFilesFallback.indexWhere((e) => e.id == fileId);
      if (idx != -1) {
        _memoryFilesFallback[idx] = _memoryFilesFallback[idx].copyWith(
          isDeleted: true,
          deletedAt: now,
        );
      }
    }
  }

  Future<void> restoreFromRecycleBin(String fileId) async {
    final db = await database;
    if (db != null) {
      await db.update(
        'vault_files',
        {'is_deleted': 0, 'deleted_at': null},
        where: 'id = ?',
        whereArgs: [fileId],
      );
    } else {
      final idx = _memoryFilesFallback.indexWhere((e) => e.id == fileId);
      if (idx != -1) {
        _memoryFilesFallback[idx] = _memoryFilesFallback[idx].copyWith(
          isDeleted: false,
        );
      }
    }
  }

  Future<void> permanentlyDeleteFile(String fileId) async {
    final db = await database;
    if (db != null) {
      await db.delete('vault_files', where: 'id = ?', whereArgs: [fileId]);
    } else {
      _memoryFilesFallback.removeWhere((e) => e.id == fileId);
    }
  }

  // Upload Queue Persistence
  Future<void> upsertQueueItem(UploadQueueItem item) async {
    final db = await database;
    if (db != null) {
      await db.insert(
        'upload_queue',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      _memoryQueueFallback.removeWhere((e) => e.id == item.id);
      _memoryQueueFallback.add(item);
    }
  }

  Future<List<UploadQueueItem>> getUploadQueue() async {
    final db = await database;
    if (db != null) {
      final rows = await db.query('upload_queue', orderBy: 'updated_at DESC');
      return rows.map(UploadQueueItem.fromMap).toList();
    } else {
      final copy = List<UploadQueueItem>.from(_memoryQueueFallback);
      copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return copy;
    }
  }

  Future<void> removeQueueItem(String id) async {
    final db = await database;
    if (db != null) {
      await db.delete('upload_queue', where: 'id = ?', whereArgs: [id]);
    } else {
      _memoryQueueFallback.removeWhere((e) => e.id == id);
    }
  }

  Future<void> clearCompletedQueueItems() async {
    final db = await database;
    if (db != null) {
      await db.delete(
        'upload_queue',
        where: 'status IN (?, ?)',
        whereArgs: [
          UploadTaskStatus.uploaded.name,
          UploadTaskStatus.skippedDuplicate.name,
        ],
      );
    } else {
      _memoryQueueFallback.removeWhere(
        (e) =>
            e.status == UploadTaskStatus.uploaded ||
            e.status == UploadTaskStatus.skippedDuplicate,
      );
    }
  }
}

