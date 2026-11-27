import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/vault_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/vault_cards.dart';
import '../../auth_otp/presentation/telegram_auth_sheet.dart';
import '../../auth_otp/providers/auth_provider.dart';
import '../../files/providers/files_provider.dart';
import '../../search/presentation/search_screen.dart';
import '../../telegram_cloud/providers/cloud_sync_provider.dart';

/// Home Screen (Tab 0) — Matches the layout & visual rhythm of reference screenshot #1
/// with the app renamed to **TeleVault** and a refined Warm Alabaster + Deep Obsidian aesthetic:
/// - Dynamic greeting ("Good evening") + bold **TeleVault** brand header + circular profile avatar `T`
/// - Quick search bar ("Search files, photos, people")
/// - Dark Obsidian "Telegram Cloud" hero card ("Your Telegram, now a cloud drive." + `Connect Telegram ->`)
/// - `Library` grouped card (`Photos & videos`, `Music`, `People`, `Starred`)
/// - `On this device` horizontal summary chips (`Images`, `Videos`, `Audio`, `Docs`)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _dynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final filesState = ref.watch(filesProvider);
    final syncState = ref.watch(cloudSyncProvider);

    final imageCount = filesState.countByCategory(FileCategory.images);
    final videoCount = filesState.countByCategory(FileCategory.videos);
    final audioCount = filesState.countByCategory(FileCategory.audio);
    final docsCount = filesState.countByCategory(FileCategory.docs);

    return Scaffold(
      backgroundColor: AppTheme.backgroundCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            // Top Greeting & Avatar Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dynamicGreeting(),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.9,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => showTelegramAuthModal(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.obsidianPill,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Search Pill Bar ("Search files, photos, people")
            GestureDetector(
              onTap: () {
                ref.read(activeTabProvider.notifier).state = 3;
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 21,
                      color: AppTheme.textPrimary,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Search files, photos, people',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Telegram Cloud Dark Hero Card
            TelegramCloudHeroCard(
              isConnected: authState.isConnected,
              connectedPhone: authState.connectedPhone,
              backedUpCount: syncState.uploadedCount,
              activeQueueCount: syncState.pendingCount,
              onPrimaryAction: () {
                if (authState.isConnected) {
                  ref.read(activeTabProvider.notifier).state = 2;
                } else {
                  showTelegramAuthModal(context);
                }
              },
              onSecondaryAction: () {
                ref
                    .read(cloudSyncProvider.notifier)
                    .syncSelectedFoldersNow();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Syncing watched folders to Telegram Cloud...'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Library Section
            const Text(
              'Library',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            GroupedSectionCard(
              children: [
                VaultMenuTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos & videos',
                  subtitle: 'On this phone',
                  onTap: () => _openLibraryCollectionSheet(
                    context,
                    ref,
                    title: 'Photos & videos',
                    subtitle: 'Camera roll, DCIM, Pictures & Movies',
                    items: filesState.allFiles
                        .where((f) =>
                            f.category == FileCategory.images ||
                            f.category == FileCategory.videos)
                        .toList(),
                  ),
                ),
                VaultMenuTile(
                  icon: Icons.library_music_outlined,
                  title: 'Music',
                  subtitle: 'Songs, albums, playlists',
                  onTap: () => _openLibraryCollectionSheet(
                    context,
                    ref,
                    title: 'Music & Audio',
                    subtitle: 'Lossless tracks, songs & voice notes',
                    items: filesState.allFiles
                        .where((f) => f.category == FileCategory.audio)
                        .toList(),
                  ),
                ),
                VaultMenuTile(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'People',
                  subtitle: 'Grouped by face',
                  onTap: () => _openPeopleGroupedSheet(
                    context,
                    ref,
                    filesState.allFiles,
                  ),
                ),
                VaultMenuTile(
                  icon: Icons.star_border_rounded,
                  title: 'Starred',
                  subtitle: 'Cloud and device',
                  onTap: () => _openLibraryCollectionSheet(
                    context,
                    ref,
                    title: 'Starred Files',
                    subtitle: 'Pinned across Telegram Cloud and device',
                    items: filesState.starredFiles,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // On this device Section
            const Text(
              'On this device',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DeviceStatChip(
                    dotColor: AppTheme.dotImages,
                    label: 'Images',
                    count: imageCount,
                    onTap: () {
                      ref.read(searchCategoryProvider.notifier).state =
                          FileCategory.images;
                      ref.read(activeTabProvider.notifier).state = 3;
                    },
                  ),
                  const SizedBox(width: 10),
                  DeviceStatChip(
                    dotColor: AppTheme.dotVideos,
                    label: 'Videos',
                    count: videoCount,
                    onTap: () {
                      ref.read(searchCategoryProvider.notifier).state =
                          FileCategory.videos;
                      ref.read(activeTabProvider.notifier).state = 3;
                    },
                  ),
                  const SizedBox(width: 10),
                  DeviceStatChip(
                    dotColor: AppTheme.dotAudio,
                    label: 'Audio',
                    count: audioCount,
                    onTap: () {
                      ref.read(searchCategoryProvider.notifier).state =
                          FileCategory.audio;
                      ref.read(activeTabProvider.notifier).state = 3;
                    },
                  ),
                  const SizedBox(width: 10),
                  DeviceStatChip(
                    dotColor: AppTheme.dotDocs,
                    label: 'Docs',
                    count: docsCount,
                    onTap: () {
                      ref.read(searchCategoryProvider.notifier).state =
                          FileCategory.docs;
                      ref.read(activeTabProvider.notifier).state = 3;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLibraryCollectionSheet(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required List<VaultFileItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (items.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final count = await ref
                                .read(cloudSyncProvider.notifier)
                                .enqueueFiles(items);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Backed up $count file(s) to Telegram Cloud queue.'),
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
                          icon: const Icon(Icons.cloud_upload_outlined,
                              size: 16),
                          label: const Text('Backup All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text('No items in this collection yet.'),
                          )
                        : ListView.builder(
                            controller: controller,
                            itemCount: items.length,
                            itemBuilder: (_, idx) {
                              final file = items[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceCard,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.folderTileBg,
                                    child: Icon(
                                      file.category.icon,
                                      color: AppTheme.folderBlue,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${file.folderName} • ${FormatUtils.formatBytes(file.sizeBytes)}${file.isBackedUp ? " • Backed up" : ""}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      file.isStarred
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: file.isStarred
                                          ? Colors.amber[700]
                                          : AppTheme.textMuted,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(filesProvider.notifier)
                                          .toggleStarred(file);
                                    },
                                  ),
                                ),
                              );
                            },
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

  void _openPeopleGroupedSheet(
    BuildContext context,
    WidgetRef ref,
    List<VaultFileItem> allFiles,
  ) {
    final grouped = <String, List<VaultFileItem>>{};
    for (final file in allFiles) {
      if (file.peopleGroup != null) {
        grouped.putIfAbsent(file.peopleGroup!, () => []).add(file);
      }
    }

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
                'People & Albums',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'On-device smart clusters organized by face & occasion',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ...grouped.entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.surfaceSubtle,
                      child: Icon(Icons.face_rounded,
                          color: AppTheme.textPrimary),
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${entry.value.length} photos & videos'),
                    trailing: TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(cloudSyncProvider.notifier)
                            .enqueueFiles(entry.value);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('Backup'),
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

