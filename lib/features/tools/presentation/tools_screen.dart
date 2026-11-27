import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/vault_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/vault_cards.dart';
import '../../files/providers/files_provider.dart';
import '../../telegram_cloud/providers/cloud_sync_provider.dart';

/// Tools Screen (Tab 4) — Matches the layout & rhythm of reference screenshot #2:
/// - Header: `Tools` + subtitle `Free up space and manage your files`
/// - Dark Obsidian `Storage analyzer` card (`90.0 GB of 224 GB used • 40%` + progress bar)
/// - `Clean up` grouped card:
///   - `Large files` ("Files over 50 MB, biggest first")
///   - `Duplicates` ("Identical copies taking extra space" via SHA-256)
///   - `Recycle bin` ("Restore or permanently delete")
/// - `Files` utilities grouped card:
///   - `Downloads` ("Open your Downloads folder")
///   - `Hidden files` ("Dot-files and hidden folders")
///   - `Compress` ("Zip files into Downloads")
///   - `Extract` ("Unpack zip, 7z or tar into Downloads")
///   - `Apps` ("Installed apps, info and APK sharing")
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesState = ref.watch(filesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const Text(
              'Tools',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.9,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Free up space and manage your files',
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 18),

            // Dark Storage Analyzer Card
            StorageAnalyzerHeroCard(
              usedLabel: '90.0 GB',
              totalLabel: '224 GB',
              percentage: 40,
              progress: 0.40,
              onTap: () =>
                  _showStorageAnalyzerSheet(context, ref, filesState),
            ),
            const SizedBox(height: 24),

            // Clean up Section
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Clean up',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GroupedSectionCard(
              children: [
                VaultMenuTile(
                  icon: Icons.insert_drive_file_rounded,
                  title: 'Large files',
                  subtitle: 'Files over 50 MB, biggest first',
                  trailing: _CountBadge(count: filesState.largeFiles.length),
                  onTap: () => _showLargeFilesSheet(context, ref),
                ),
                VaultMenuTile(
                  icon: Icons.copy_all_rounded,
                  title: 'Duplicates',
                  subtitle: 'Identical copies taking extra space',
                  trailing:
                      _CountBadge(count: filesState.duplicateGroups.length),
                  onTap: () => _showDuplicatesSheet(context, ref),
                ),
                VaultMenuTile(
                  icon: Icons.delete_rounded,
                  title: 'Recycle bin',
                  subtitle: 'Restore or permanently delete',
                  trailing: _CountBadge(count: filesState.deletedFiles.length),
                  onTap: () => _showRecycleBinSheet(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Files Utilities Section
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Files',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GroupedSectionCard(
              children: [
                VaultMenuTile(
                  icon: Icons.download_rounded,
                  title: 'Downloads',
                  subtitle: 'Open your Downloads folder',
                  onTap: () {
                    ref.read(filesProvider.notifier).openFolder('Download');
                    ref.read(activeTabProvider.notifier).state = 1;
                  },
                ),
                VaultMenuTile(
                  icon: Icons.visibility_off_rounded,
                  title: 'Hidden files',
                  subtitle: 'Dot-files and hidden folders',
                  trailing: _CountBadge(count: filesState.hiddenFiles.length),
                  onTap: () => _showHiddenFilesSheet(context, ref),
                ),
                VaultMenuTile(
                  icon: Icons.archive_rounded,
                  title: 'Compress',
                  subtitle: 'Zip files into Downloads',
                  onTap: () => _showCompressSheet(context, ref),
                ),
                VaultMenuTile(
                  icon: Icons.unarchive_rounded,
                  title: 'Extract',
                  subtitle: 'Unpack zip, 7z or tar into Downloads',
                  onTap: () => _showExtractSheet(context, ref),
                ),
                VaultMenuTile(
                  icon: Icons.android_rounded,
                  title: 'Apps',
                  subtitle: 'Installed apps, info and APK sharing',
                  onTap: () => _showAppsSheet(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1. Storage Analyzer Detail Breakdown Sheet
  void _showStorageAnalyzerSheet(
    BuildContext context,
    WidgetRef ref,
    FilesState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Storage Analyzer Breakdown',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                '90.0 GB used of 224 GB (134.0 GB free on device)',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              const _StorageBreakdownBarRow(
                label: 'Videos (4K / HDR)',
                sizeLabel: '38.4 GB',
                color: AppTheme.dotVideos,
                ratio: 0.42,
              ),
              const SizedBox(height: 12),
              const _StorageBreakdownBarRow(
                label: 'Images & RAW Photos',
                sizeLabel: '22.1 GB',
                color: AppTheme.dotImages,
                ratio: 0.25,
              ),
              const SizedBox(height: 12),
              const _StorageBreakdownBarRow(
                label: 'Apps & APK Packages',
                sizeLabel: '16.5 GB',
                color: AppTheme.dotApps,
                ratio: 0.18,
              ),
              const SizedBox(height: 12),
              const _StorageBreakdownBarRow(
                label: 'Documents & Archives',
                sizeLabel: '8.2 GB',
                color: AppTheme.dotDocs,
                ratio: 0.09,
              ),
              const SizedBox(height: 12),
              const _StorageBreakdownBarRow(
                label: 'Audio & Lossless Music',
                sizeLabel: '4.8 GB',
                color: AppTheme.dotAudio,
                ratio: 0.06,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showLargeFilesSheet(context, ref);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.obsidianPill,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                  label: const Text('Inspect Large Files (>50 MB)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Large Files (>50 MB) Sheet
  void _showLargeFilesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final largeFiles = ref.watch(filesProvider).largeFiles;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Large files (> 50 MB)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Back up large videos & archives to Telegram Cloud, then move local copies to Recycle bin to free space.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (largeFiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('No files over 50 MB found on device.')),
                    )
                  else
                    ...largeFiles.map(
                      (file) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.folderTileBg,
                            child: Icon(file.category.icon,
                                color: AppTheme.folderBlue, size: 20),
                          ),
                          title: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${FormatUtils.formatBytes(file.sizeBytes)} • ${file.folderName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Back up to Telegram',
                                icon: const Icon(Icons.cloud_upload_outlined,
                                    color: AppTheme.telegramBlue),
                                onPressed: () async {
                                  await ref
                                      .read(cloudSyncProvider.notifier)
                                      .enqueueFiles([file]);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Queued "${file.name}" for Telegram backup.'),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Move to Recycle Bin',
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppTheme.danger),
                                onPressed: () => ref
                                    .read(filesProvider.notifier)
                                    .moveToRecycleBin(file.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. SHA-256 Duplicates Scanner & Cleanup Sheet
  void _showDuplicatesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final groups = ref.watch(filesProvider).duplicateGroups;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHA-256 Duplicate Finder',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Identical files detected via SHA-256 content digest',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (groups.isNotEmpty)
                        ElevatedButton(
                          onPressed: () async {
                            for (final group in groups) {
                              for (var i = 1; i < group.files.length; i++) {
                                await ref
                                    .read(filesProvider.notifier)
                                    .moveToRecycleBin(group.files[i].id);
                              }
                            }
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Moved extra duplicate copies to Recycle bin.'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.obsidianPill,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Clean Extra Copies'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                            'No duplicate files detected! Your storage is clean.'),
                      ),
                    )
                  else
                    ...groups.map(
                      (g) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.fingerprint_rounded,
                                    size: 16, color: AppTheme.telegramBlue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'SHA-256: ${g.sha256Hash.substring(0, 18)}... • Reclaim ${FormatUtils.formatBytes(g.reclaimableBytes)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.telegramBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...g.files.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final f = entry.value;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  f.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                    '${f.folderName} • ${FormatUtils.formatBytes(f.sizeBytes)}${idx == 0 ? " (Original Kept)" : " (Duplicate Copy)"}'),
                                trailing: idx == 0
                                    ? const Chip(
                                        label: Text('Original',
                                            style: TextStyle(fontSize: 11)),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppTheme.danger),
                                        onPressed: () => ref
                                            .read(filesProvider.notifier)
                                            .moveToRecycleBin(f.id),
                                      ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 4. Recycle Bin Sheet
  void _showRecycleBinSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final deleted = ref.watch(filesProvider).deletedFiles;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recycle bin',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Restore accidentally removed files or permanently erase them',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  if (deleted.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Recycle bin is empty.')),
                    )
                  else
                    ...deleted.map(
                      (file) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          title: Text(
                            file.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                              '${file.folderName} • ${FormatUtils.formatBytes(file.sizeBytes)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => ref
                                    .read(filesProvider.notifier)
                                    .restoreFromRecycleBin(file.id),
                                child: const Text('Restore'),
                              ),
                              IconButton(
                                tooltip: 'Delete Permanently',
                                icon: const Icon(Icons.delete_forever_rounded,
                                    color: AppTheme.danger),
                                onPressed: () => ref
                                    .read(filesProvider.notifier)
                                    .permanentlyDeleteFile(file.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 5. Hidden Files Sheet
  void _showHiddenFilesSheet(BuildContext context, WidgetRef ref) {
    final hidden = ref.read(filesProvider).hiddenFiles;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hidden files & dot-folders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'System dot-files (.nomedia, cache indexes) visible where OS permissions allow',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ...hidden.map(
                (file) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.visibility_off_outlined,
                        color: AppTheme.textSecondary),
                    title: Text(file.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${file.path} • ${FormatUtils.formatBytes(file.sizeBytes)}'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 6. Compress Utility Sheet
  void _showCompressSheet(BuildContext context, WidgetRef ref) {
    final files = ref
        .read(filesProvider)
        .allFiles
        .where((f) => !f.isDeleted)
        .take(6)
        .toList();
    final selectedIds = <String>{
      if (files.isNotEmpty) files.first.id,
    };
    final nameCtrl =
        TextEditingController(text: 'TeleVault_Bundle_2026.zip');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compress files into Downloads',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Output Zip Archive Name',
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...files.map(
                    (f) => CheckboxListTile(
                      value: selectedIds.contains(f.id),
                      title: Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(FormatUtils.formatBytes(f.sizeBytes)),
                      onChanged: (v) {
                        setSheetState(() {
                          if (v == true) {
                            selectedIds.add(f.id);
                          } else {
                            selectedIds.remove(f.id);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: selectedIds.isEmpty
                          ? null
                          : () async {
                              final chosen = files
                                  .where((f) => selectedIds.contains(f.id))
                                  .toList();
                              final zip = await ref
                                  .read(filesProvider.notifier)
                                  .compressFilesToZip(
                                    files: chosen,
                                    archiveBaseName: nameCtrl.text.trim(),
                                  );
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Created archive ${zip.name} in Downloads.'),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.obsidianPill,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.archive_rounded, size: 18),
                      label: const Text('Create .ZIP in Downloads'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 7. Extract Utility Sheet
  void _showExtractSheet(BuildContext context, WidgetRef ref) {
    final archives = ref
        .read(filesProvider)
        .allFiles
        .where((f) =>
            !f.isDeleted &&
            (f.name.toLowerCase().endsWith('.zip') ||
                f.name.toLowerCase().endsWith('.tar') ||
                f.name.toLowerCase().endsWith('.7z')))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Extract archive into Downloads',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a .zip, .tar, or .7z archive to unpack into your Downloads folder',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              if (archives.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No archive files found.')),
                )
              else
                ...archives.map(
                  (arch) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.folder_zip_rounded,
                          color: AppTheme.folderBlue),
                      title: Text(arch.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${arch.folderName} • ${FormatUtils.formatBytes(arch.sizeBytes)}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final extracted = await ref
                              .read(filesProvider.notifier)
                              .extractArchiveToDownloads(arch);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Extracted "${extracted.name}" to Downloads.'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.obsidianPill,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Unpack'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 8. Installed Apps & APK Manager Sheet
  void _showAppsSheet(BuildContext context, WidgetRef ref) {
    final apks = ref
        .read(filesProvider)
        .allFiles
        .where((f) => !f.isDeleted && f.category == FileCategory.apps)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apps & APK Packages',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage local APK installers and back them up to Telegram Cloud',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ...apks.map(
                (apk) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.android_rounded,
                          color: AppTheme.dotApps),
                    ),
                    title: Text(apk.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${apk.folderName} • ${FormatUtils.formatBytes(apk.sizeBytes)}'),
                    trailing: TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(cloudSyncProvider.notifier)
                            .enqueueFiles([apk]);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Backed up ${apk.name} to Telegram Cloud.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('Backup APK'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _StorageBreakdownBarRow extends StatelessWidget {
  final String label;
  final String sizeLabel;
  final Color color;
  final double ratio;

  const _StorageBreakdownBarRow({
    required this.label,
    required this.sizeLabel,
    required this.color,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              sizeLabel,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppTheme.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

