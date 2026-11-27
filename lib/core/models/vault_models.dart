import 'package:flutter/material.dart';

/// Categories of files supported across Home chips, Search filter pills, and Storage Analyzer.
enum FileCategory {
  all,
  images,
  videos,
  audio,
  docs,
  apps,
}

extension FileCategoryExtension on FileCategory {
  String get label {
    switch (this) {
      case FileCategory.all:
        return 'All';
      case FileCategory.images:
        return 'Images';
      case FileCategory.videos:
        return 'Videos';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.docs:
        return 'Docs';
      case FileCategory.apps:
        return 'Apps';
    }
  }

  IconData get icon {
    switch (this) {
      case FileCategory.all:
        return Icons.grid_view_rounded;
      case FileCategory.images:
        return Icons.photo_library_outlined;
      case FileCategory.videos:
        return Icons.videocam_outlined;
      case FileCategory.audio:
        return Icons.music_note_outlined;
      case FileCategory.docs:
        return Icons.description_outlined;
      case FileCategory.apps:
        return Icons.android_outlined;
    }
  }
}

/// Represents a device folder in Internal Storage (e.g., Android, DCIM, Documents, Download).
class DeviceFolderItem {
  final String name;
  final String path;
  final DateTime lastModified;
  final int itemCount;
  final int totalBytes;
  final bool isHidden;

  const DeviceFolderItem({
    required this.name,
    required this.path,
    required this.lastModified,
    this.itemCount = 0,
    this.totalBytes = 0,
    this.isHidden = false,
  });

  DeviceFolderItem copyWith({
    String? name,
    String? path,
    DateTime? lastModified,
    int? itemCount,
    int? totalBytes,
    bool? isHidden,
  }) {
    return DeviceFolderItem(
      name: name ?? this.name,
      path: path ?? this.path,
      lastModified: lastModified ?? this.lastModified,
      itemCount: itemCount ?? this.itemCount,
      totalBytes: totalBytes ?? this.totalBytes,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}

/// Represents an indexed file on the device or backed up to Telegram Cloud.
class VaultFileItem {
  final String id;
  final String name;
  final String path;
  final String folderName;
  final int sizeBytes;
  final DateTime modifiedAt;
  final FileCategory category;
  final String? sha256Hash;
  final bool isStarred;
  final bool isBackedUp;
  final bool isHidden;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? peopleGroup; // For Library -> People grouping

  const VaultFileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.folderName,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.category,
    this.sha256Hash,
    this.isStarred = false,
    this.isBackedUp = false,
    this.isHidden = false,
    this.isDeleted = false,
    this.deletedAt,
    this.peopleGroup,
  });

  VaultFileItem copyWith({
    String? id,
    String? name,
    String? path,
    String? folderName,
    int? sizeBytes,
    DateTime? modifiedAt,
    FileCategory? category,
    String? sha256Hash,
    bool? isStarred,
    bool? isBackedUp,
    bool? isHidden,
    bool? isDeleted,
    DateTime? deletedAt,
    String? peopleGroup,
  }) {
    return VaultFileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      folderName: folderName ?? this.folderName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      category: category ?? this.category,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      isStarred: isStarred ?? this.isStarred,
      isBackedUp: isBackedUp ?? this.isBackedUp,
      isHidden: isHidden ?? this.isHidden,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      peopleGroup: peopleGroup ?? this.peopleGroup,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'folder_name': folderName,
      'size_bytes': sizeBytes,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'category': category.name,
      'sha256_hash': sha256Hash,
      'is_starred': isStarred ? 1 : 0,
      'is_backed_up': isBackedUp ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'people_group': peopleGroup,
    };
  }

  factory VaultFileItem.fromMap(Map<String, dynamic> map) {
    final categoryStr = (map['category'] as String?) ?? 'docs';
    final category = FileCategory.values.firstWhere(
      (e) => e.name == categoryStr,
      orElse: () => FileCategory.docs,
    );
    return VaultFileItem(
      id: map['id'] as String,
      name: map['name'] as String,
      path: map['path'] as String,
      folderName: map['folder_name'] as String,
      sizeBytes: (map['size_bytes'] as num).toInt(),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified_at'] as num).toInt(),
      ),
      category: category,
      sha256Hash: map['sha256_hash'] as String?,
      isStarred: (map['is_starred'] as int? ?? 0) == 1,
      isBackedUp: (map['is_backed_up'] as int? ?? 0) == 1,
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['deleted_at'] as num).toInt())
          : null,
      peopleGroup: map['people_group'] as String?,
    );
  }
}

/// Upload Queue Item Status
enum UploadTaskStatus {
  pending,
  uploading,
  uploaded,
  paused,
  failed,
  skippedDuplicate,
}

extension UploadTaskStatusExt on UploadTaskStatus {
  String get label {
    switch (this) {
      case UploadTaskStatus.pending:
        return 'Pending';
      case UploadTaskStatus.uploading:
        return 'Uploading';
      case UploadTaskStatus.uploaded:
        return 'Backed Up';
      case UploadTaskStatus.paused:
        return 'Paused';
      case UploadTaskStatus.failed:
        return 'Failed';
      case UploadTaskStatus.skippedDuplicate:
        return 'Skipped (Duplicate)';
    }
  }
}

/// Represents a file queued or completed in the Telegram Cloud Upload Queue.
class UploadQueueItem {
  final String id;
  final String fileId;
  final String fileName;
  final String filePath;
  final String folderName;
  final int sizeBytes;
  final String sha256Hash;
  final UploadTaskStatus status;
  final double progress;
  final String? telegramMessageId;
  final String? errorMessage;
  final DateTime updatedAt;

  const UploadQueueItem({
    required this.id,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.folderName,
    required this.sizeBytes,
    required this.sha256Hash,
    required this.status,
    this.progress = 0.0,
    this.telegramMessageId,
    this.errorMessage,
    required this.updatedAt,
  });

  UploadQueueItem copyWith({
    UploadTaskStatus? status,
    double? progress,
    String? telegramMessageId,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return UploadQueueItem(
      id: id,
      fileId: fileId,
      fileName: fileName,
      filePath: filePath,
      folderName: folderName,
      sizeBytes: sizeBytes,
      sha256Hash: sha256Hash,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'file_name': fileName,
      'file_path': filePath,
      'folder_name': folderName,
      'size_bytes': sizeBytes,
      'sha256_hash': sha256Hash,
      'status': status.name,
      'progress': progress,
      'telegram_message_id': telegramMessageId,
      'error_message': errorMessage,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UploadQueueItem.fromMap(Map<String, dynamic> map) {
    final statusName = (map['status'] as String?) ?? 'pending';
    final status = UploadTaskStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => UploadTaskStatus.pending,
    );
    return UploadQueueItem(
      id: map['id'] as String,
      fileId: map['file_id'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      folderName: map['folder_name'] as String,
      sizeBytes: (map['size_bytes'] as num).toInt(),
      sha256Hash: map['sha256_hash'] as String,
      status: status,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      telegramMessageId: map['telegram_message_id'] as String?,
      errorMessage: map['error_message'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
    );
  }
}

/// Group of duplicate files sharing an identical SHA-256 hash or size+name signature.
class DuplicateGroup {
  final String sha256Hash;
  final List<VaultFileItem> files;

  const DuplicateGroup({
    required this.sha256Hash,
    required this.files,
  });

  int get reclaimableBytes {
    if (files.length <= 1) return 0;
    return files.first.sizeBytes * (files.length - 1);
  }
}

