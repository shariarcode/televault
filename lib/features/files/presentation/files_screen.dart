import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/vault_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../telegram_cloud/providers/cloud_sync_provider.dart';
import '../providers/files_provider.dart';

/// Files Screen (Tab 1: Internal Storage & Folders) — Matches reference screenshot #5:
/// - Top Header: `Internal Storage` title + 3 circular white action buttons (`Search`, `Sort`, `Grid/List toggle`)
/// - Folder Cards: `Android`, `DCIM`, `Documents`, `Download`, `Fonts`, `MIUI`, `Movies`, `Music`,
///   `MxPlayerAd`, `Notifications`, `Pictures` with soft blue folder icon tile, folder name,
///   formatted last-modified date (`Jul 16, 2026`, `Nov 25, 2026`, etc.), and 3-dot overflow menu.
/// - Tapping any folder drills down into its files with multi-select and one-tap "Upload to Telegram Cloud".
class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesState = ref.watch(filesProvider);
    final notifier = ref.read(filesProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.backgroundCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  if (filesState.activeFolderName != null) ...[
                    GestureDetector(
                      onTap: () => notifier.openFolder(null),
                      child: Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceCard,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      filesState.activeFolderName ?? 'Internal Storage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  _CircleActionIconButton(
                    icon: Icons.search_rounded,
                    tooltip: 'Search files',
                    onTap: () =>
                        ref.read(activeTabProvider.notifier).state = 3,
                  ),
                  const SizedBox(width: 8),
                  _CircleActionIconButton(
                    icon: Icons.sort_rounded,
                    tooltip: 'Sort options',
                    onTap: () => _showSortSheet(context, ref, filesState.sortMode),
                  ),
                  const SizedBox(width: 8),
                  _CircleActionIconButton(
                    icon: filesState.isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    tooltip: 'Toggle Grid / List view',
                    onTap: notifier.toggleGridView,
                  ),
                ],
              ),
            ),

            // Multi-select action bar when files are selected
            if (filesState.selectedFileIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      '${filesState.selectedFileIds.length} selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final selectedFiles = filesState.allFiles
                            .where((f) =>
                                filesState.selectedFileIds.contains(f.id))
                            .toList();
                        final count = await ref
                            .read(cloudSyncProvider.notifier)
                            .enqueueFiles(selectedFiles);
                        notifier.clearSelection();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Queued $count file(s) for Telegram Cloud upload.'),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.telegramSky,
                      ),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: const Text('Upload'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 18),
                      onPressed: notifier.clearSelection,
                    ),
                  ],
                ),
              ),

            // Content Area: Either Root Internal Storage Folders or Inside a Selected Folder
            Expanded(
              child: filesState.activeFolderName == null
                  ? _buildRootFoldersView(context, ref, filesState)
                  : _buildFolderFilesView(context, ref, filesState),
            ),
          ],
        ),
      ),
      floatingActionButton: filesState.activeFolderName != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final imported = await notifier.pickAndImportDeviceFiles(
                  targetFolder: filesState.activeFolderName,
                );
                if (imported.isNotEmpty && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Imported ${imported.length} file(s) into ${filesState.activeFolderName}.'),
                    ),
                  );
                }
              },
              backgroundColor: AppTheme.obsidianPill,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Import / Upload File'),
            )
          : null,
    );
  }

  Widget _buildRootFoldersView(
    BuildContext context,
    WidgetRef ref,
    FilesState state,
  ) {
    final dateFmt = DateFormat('MMM dd, yyyy');

    if (state.isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.28,
        ),
        itemCount: state.folders.length,
        itemBuilder: (context, index) {
          final folder = state.folders[index];
          return InkWell(
            onTap: () =>
                ref.read(filesProvider.notifier).openFolder(folder.name),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.folderTileBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: AppTheme.folderBlue,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      _buildFolderPopupMenu(context, ref, folder),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFmt.format(folder.lastModified),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: state.folders.length,
      itemBuilder: (context, index) {
        final folder = state.folders[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 11),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.018),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  ref.read(filesProvider.notifier).openFolder(folder.name),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.folderTileBg,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.folder_rounded,
                        color: AppTheme.folderBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateFmt.format(folder.lastModified),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildFolderPopupMenu(context, ref, folder),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderPopupMenu(
    BuildContext context,
    WidgetRef ref,
    DeviceFolderItem folder,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF8C8F99),
        size: 20,
      ),
      onSelected: (action) async {
        final folderFiles = ref
            .read(filesProvider)
            .allFiles
            .where((f) => !f.isDeleted && f.folderName == folder.name)
            .toList();

        if (action == 'backup_folder') {
          if (folderFiles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Folder "${folder.name}" has no files to back up.')),
            );
            return;
          }
          final count = await ref
              .read(cloudSyncProvider.notifier)
              .enqueueFiles(folderFiles);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Queued $count file(s) from ${folder.name} to Telegram Cloud.'),
              ),
            );
          }
        } else if (action == 'zip_folder') {
          if (folderFiles.isEmpty) return;
          final zip = await ref
              .read(filesProvider.notifier)
              .compressFilesToZip(
                files: folderFiles,
                archiveBaseName: '${folder.name}_Backup.zip',
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Compressed into Download/${zip.name}'),
              ),
            );
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'backup_folder',
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 18),
              SizedBox(width: 10),
              Text('Back up folder to Telegram'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'zip_folder',
          child: Row(
            children: [
              Icon(Icons.folder_zip_outlined, size: 18),
              SizedBox(width: 10),
              Text('Compress to Download (.zip)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderFilesView(
    BuildContext context,
    WidgetRef ref,
    FilesState state,
  ) {
    final files = state.currentFolderFiles;
    final notifier = ref.read(filesProvider.notifier);
    final dateFmt = DateFormat('MMM dd, yyyy');

    if (files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 30,
                  color: AppTheme.folderBlue,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No files in ${state.activeFolderName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap "Import / Upload File" below to pick files from your device and back them up to Telegram Cloud.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = state.selectedFileIds.contains(file.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.telegramBlue.withOpacity(0.08)
                : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: AppTheme.telegramBlue, width: 1.4)
                : null,
          ),
          child: ListTile(
            onTap: () => notifier.toggleSelectFile(file.id),
            onLongPress: () => notifier.toggleSelectFile(file.id),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.folderTileBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : file.category.icon,
                color: AppTheme.folderBlue,
              ),
            ),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${FormatUtils.formatBytes(file.sizeBytes)} • ${dateFmt.format(file.modifiedAt)}${file.isBackedUp ? " • ☁️ Synced" : ""}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'upload') {
                  await ref
                      .read(cloudSyncProvider.notifier)
                      .enqueueFiles([file]);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Queued "${file.name}" for Telegram Cloud.'),
                      ),
                    );
                  }
                } else if (action == 'star') {
                  await notifier.toggleStarred(file);
                } else if (action == 'delete') {
                  await notifier.moveToRecycleBin(file.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'upload',
                  child: Text('Upload to Telegram Cloud'),
                ),
                PopupMenuItem(
                  value: 'star',
                  child: Text(
                      file.isStarred ? 'Remove from Starred' : 'Add to Starred'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Move to Recycle bin'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortSheet(
    BuildContext context,
    WidgetRef ref,
    FilesSortMode current,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort files & folders by',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              RadioListTile<FilesSortMode>(
                value: FilesSortMode.nameAsc,
                groupValue: current,
                title: const Text('Name (A to Z)'),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(filesProvider.notifier).setSortMode(v);
                    Navigator.of(ctx).pop();
                  }
                },
              ),
              RadioListTile<FilesSortMode>(
                value: FilesSortMode.dateDesc,
                groupValue: current,
                title: const Text('Last modified (Newest first)'),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(filesProvider.notifier).setSortMode(v);
                    Navigator.of(ctx).pop();
                  }
                },
              ),
              RadioListTile<FilesSortMode>(
                value: FilesSortMode.sizeDesc,
                groupValue: current,
                title: const Text('Size (Largest first)'),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(filesProvider.notifier).setSortMode(v);
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.surfaceCard,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

