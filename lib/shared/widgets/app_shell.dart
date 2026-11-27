import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/files/presentation/files_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/telegram_cloud/presentation/telegram_cloud_screen.dart';
import '../../features/telegram_cloud/providers/cloud_sync_provider.dart';
import '../../features/tools/presentation/tools_screen.dart';

/// Active bottom navigation tab index provider (`0`: Home, `1`: Files, `2`: Telegram Cloud, `3`: Search, `4`: Tools).
final activeTabProvider = StateProvider<int>((ref) => 0);

/// Main 5-destination Shell matching the floating pill bottom navigation bar from the reference screenshots:
/// - `Home` (expanding dark active pill with icon + label)
/// - `Files` (expanding dark active pill with icon + label)
/// - Center `Telegram Cloud` hub (circular dark active badge or blue paper-plane with status dot)
/// - `Search` (expanding dark active pill with icon + label)
/// - `Tools` (expanding dark active pill with icon + label)
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(activeTabProvider);
    final cloudState = ref.watch(cloudSyncProvider);

    final screens = const [
      HomeScreen(),
      FilesScreen(),
      TelegramCloudScreen(),
      SearchScreen(),
      ToolsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavPillButton(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () =>
                      ref.read(activeTabProvider.notifier).state = 0,
                ),
                _NavPillButton(
                  icon: Icons.folder_rounded,
                  label: 'Files',
                  isSelected: currentIndex == 1,
                  onTap: () =>
                      ref.read(activeTabProvider.notifier).state = 1,
                ),
                _CenterTelegramNavButton(
                  isSelected: currentIndex == 2,
                  hasActiveSync: cloudState.isUploading ||
                      cloudState.pendingCount > 0,
                  onTap: () =>
                      ref.read(activeTabProvider.notifier).state = 2,
                ),
                _NavPillButton(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: currentIndex == 3,
                  onTap: () =>
                      ref.read(activeTabProvider.notifier).state = 3,
                ),
                _NavPillButton(
                  icon: Icons.grid_view_rounded,
                  label: 'Tools',
                  isSelected: currentIndex == 4,
                  onTap: () =>
                      ref.read(activeTabProvider.notifier).state = 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavPillButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.obsidianPill : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: isSelected ? Colors.white : const Color(0xFF8C8F99),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CenterTelegramNavButton extends StatelessWidget {
  final bool isSelected;
  final bool hasActiveSync;
  final VoidCallback onTap;

  const _CenterTelegramNavButton({
    required this.isSelected,
    required this.hasActiveSync,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.obsidianPill : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.35,
              child: Icon(
                Icons.send_rounded,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF2855B8),
              ),
            ),
            Positioned(
              top: 11,
              right: 11,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: hasActiveSync
                      ? AppTheme.telegramBlue
                      : const Color(0xFF9CA3AF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

