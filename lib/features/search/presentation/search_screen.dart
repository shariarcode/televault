import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/vault_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../files/providers/files_provider.dart';
import '../../telegram_cloud/providers/cloud_sync_provider.dart';

/// Selected category pill provider on the Search Screen (`All`, `Images`, `Videos`, `Audio`, `Docs`, `Apps`).
final searchCategoryProvider =
    StateProvider<FileCategory>((ref) => FileCategory.all);

/// Search query text provider.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search Screen (Tab 3) — Matches reference screenshot #3:
/// - Circular white Back button (`<-`) + rounded white search input pill (`Search files and folders`)
/// - Horizontal filter pills (`All`, `Images`, `Videos`, `Audio`, `Docs`, `Apps`) with high-contrast dark active pill
/// - Empty state ("Search your files • Find anything by name, type or folder.") when query is empty & category is `All`
/// - Dynamic real-time results for matching files & folders with instant "Upload to Telegram Cloud" action
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(searchCategoryProvider);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final filesState = ref.watch(filesProvider);

    final matchingFolders = filesState.folders.where((folder) {
      if (selectedCategory != FileCategory.all) return false;
      if (query.isEmpty) return false;
      return folder.name.toLowerCase().contains(query);
    }).toList();

    final matchingFiles = filesState.allFiles.where((file) {
      if (file.isDeleted) return false;
      final categoryMatches = selectedCategory == FileCategory.all ||
          file.category == selectedCategory;
      if (!categoryMatches) return false;

      if (query.isEmpty) {
        // Show category items immediately when a specific filter pill is tapped
        return selectedCategory != FileCategory.all;
      }

      return file.name.toLowerCase().contains(query) ||
          file.folderName.toLowerCase().contains(query) ||
          file.category.label.toLowerCase().contains(query);
    }).toList();

    final showInitialPrompt =
        query.isEmpty && selectedCategory == FileCategory.all;

    return Scaffold(
      backgroundColor: AppTheme.backgroundCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Search Bar Row (Circular Back button + Search Input Pill)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(activeTabProvider.notifier).state = 0;
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceCard,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) => ref
                                  .read(searchQueryProvider.notifier)
                                  .state = val,
                              decoration: const InputDecoration(
                                hintText: 'Search files and folders',
                                hintStyle: TextStyle(
                                  fontSize: 14.5,
                                  color: AppTheme.textMuted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                ref.read(searchQueryProvider.notifier).state =
                                    '';
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Category Filter Pills (`All`, `Images`, `Videos`, `Audio`, `Docs`, `Apps`)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: FileCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryFilterPill(
                      label: category.label,
                      isSelected: selectedCategory == category,
                      onTap: () {
                        ref.read(searchCategoryProvider.notifier).state =
                            category;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Search Results or Empty State Center Prompt
            Expanded(
              child: showInitialPrompt
                  ? _buildCenterEmptyPrompt()
                  : (matchingFolders.isEmpty && matchingFiles.isEmpty)
                      ? _buildNoMatchesFound(query, selectedCategory)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            if (matchingFolders.isNotEmpty) ...[
                              const Text(
                                'Folders',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...matchingFolders.map(
                                (folder) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceCard,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      ref
                                          .read(filesProvider.notifier)
                                          .openFolder(folder.name);
                                      ref
                                          .read(activeTabProvider.notifier)
                                          .state = 1;
                                    },
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.folderTileBg,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Icon(
                                        Icons.folder_rounded,
                                        color: AppTheme.folderBlue,
                                      ),
                                    ),
                                    title: Text(
                                      folder.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle:
                                        Text('${folder.itemCount} file(s)'),
                                    trailing: const Icon(
                                        Icons.chevron_right_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (matchingFiles.isNotEmpty) ...[
                              Text(
                                'Files (${matchingFiles.length})',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...matchingFiles.map(
                                (file) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceCard,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.folderTileBg,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
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
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${file.folderName} • ${FormatUtils.formatBytes(file.sizeBytes)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Upload to Telegram Cloud',
                                      icon: Icon(
                                        file.isBackedUp
                                            ? Icons.cloud_done_rounded
                                            : Icons.cloud_upload_outlined,
                                        color: file.isBackedUp
                                            ? AppTheme.success
                                            : AppTheme.telegramBlue,
                                      ),
                                      onPressed: () async {
                                        await ref
                                            .read(cloudSyncProvider.notifier)
                                            .enqueueFiles([file]);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Queued "${file.name}" for Telegram Cloud backup.'),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 30,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Search your files',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Find anything by name, type or folder.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesFound(String query, FileCategory category) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No ${category == FileCategory.all ? "files" : category.label.toLowerCase()} matching "$query"',
          style: const TextStyle(
            fontSize: 14.5,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

