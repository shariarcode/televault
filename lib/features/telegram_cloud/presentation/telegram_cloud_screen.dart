import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/vault_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth_otp/presentation/telegram_auth_sheet.dart';
import '../../auth_otp/providers/auth_provider.dart';
import '../providers/cloud_sync_provider.dart';

/// Center Bottom Navigation Tab: Telegram Cloud Screen.
///
/// - When **Disconnected**: Follows the exact layout & pace of reference screenshot #4
///   ("Your Telegram, as a cloud drive. Sign in once. Your files live in your own Telegram account — TeleVault keeps the folders."
///   with `Private`, `Everywhere`, `Free` feature rows, Security Warning notice, and bottom pill CTA `Connect Telegram`).
/// - When **Connected**: Transforms into the full Cloud Sync & Queue Control Hub
///   (Connected session card, Auto-backup rules, Album selection, Wi-Fi only, SHA-256 duplicate prevention,
///   Sync Now trigger, and live Upload Queue with pause/resume/cancel).
class TelegramCloudScreen extends ConsumerWidget {
  const TelegramCloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(cloudSyncProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundCanvas,
      body: SafeArea(
        child: authState.isConnected
            ? _ConnectedCloudHub(
                authState: authState,
                syncState: syncState,
              )
            : _DisconnectedOnboardingView(
                onConnectTap: () => showTelegramAuthModal(context),
              ),
      ),
    );
  }
}

class _DisconnectedOnboardingView extends StatelessWidget {
  final VoidCallback onConnectTap;

  const _DisconnectedOnboardingView({
    required this.onConnectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.telegramSky, AppTheme.telegramBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.telegramBlue.withOpacity(0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Your Telegram,\nas a cloud drive.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.14,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sign in once. Your files live in your own Telegram account — TeleVault keeps the folders.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _OnboardingBenefitRow(
                    icon: Icons.lock_rounded,
                    title: 'Private',
                    subtitle: 'Only you can see your files',
                  ),
                  const SizedBox(height: 20),
                  const _OnboardingBenefitRow(
                    icon: Icons.devices_rounded,
                    title: 'Everywhere',
                    subtitle: 'Phone, web, Mac and iPhone',
                  ),
                  const SizedBox(height: 20),
                  const _OnboardingBenefitRow(
                    icon: Icons.cloud_outlined,
                    title: 'Free',
                    subtitle: 'Uses the storage Telegram gives you',
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: AppTheme.telegramBlue,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Safety Tip: Enable Telegram Two-Step Verification and avoid storing unencrypted sensitive IDs (NIDs, passports, banking data) in cloud chats.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: onConnectTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.obsidianPill,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 19),
              label: const Text(
                'Connect Telegram',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingBenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: AppTheme.textPrimary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectedCloudHub extends ConsumerWidget {
  final AuthState authState;
  final CloudSyncState syncState;

  const _ConnectedCloudHub({
    required this.authState,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cloudSyncProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Telegram Cloud',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Auto-backup, SHA-256 deduplication & upload queue',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Account & Bridge Settings',
              onPressed: () => showTelegramAuthModal(context),
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.manage_accounts_outlined, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Connected Account Dark Status Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10131C), Color(0xFF192132)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.telegramBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_done_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.connectedUsername ?? 'Saved Messages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          authState.isDemoMode
                              ? 'MTProto Bridge • Simulation Mode'
                              : authState.bridgeUrl,
                          style: const TextStyle(
                            color: AppTheme.textOnDarkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(authProvider.notifier).disconnectTelegram(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _CloudMetricPill(
                    label: 'Backed Up',
                    value: '${syncState.uploadedCount}',
                  ),
                  const SizedBox(width: 10),
                  _CloudMetricPill(
                    label: 'In Queue',
                    value: '${syncState.pendingCount}',
                  ),
                  const SizedBox(width: 10),
                  _CloudMetricPill(
                    label: 'Dedup Skipped',
                    value: '${syncState.skippedDuplicatesCount}',
                  ),
                ],
              ),
              if (syncState.queue.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      syncState.isUploading
                          ? 'Uploading to Saved Messages...'
                          : (syncState.isQueuePaused
                              ? 'Queue Paused'
                              : 'Queue Complete'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      '${(syncState.overallProgress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: syncState.overallProgress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.14),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.telegramSky),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.syncSelectedFoldersNow(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text(
                        'Sync Now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (syncState.pendingCount > 0 || syncState.isQueuePaused)
                    OutlinedButton.icon(
                      onPressed: () => syncState.isQueuePaused
                          ? notifier.resumeQueue()
                          : notifier.pauseQueue(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: Icon(
                        syncState.isQueuePaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 18,
                      ),
                      label: Text(syncState.isQueuePaused ? 'Resume' : 'Pause'),
                    ),
                ],
              ),
            ],
          ),
        ),

        if (syncState.lastSyncMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 17, color: AppTheme.telegramBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncState.lastSyncMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),
        const Text(
          'Auto-Backup Rules',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  'Auto-backup folders to Telegram',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Automatically queue new photos & docs from selected folders',
                  style: TextStyle(fontSize: 12),
                ),
                value: syncState.autoBackupEnabled,
                activeColor: AppTheme.obsidianPill,
                onChanged: notifier.toggleAutoBackup,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                  'Wi-Fi only',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Pause auto-uploads on metered cellular networks',
                  style: TextStyle(fontSize: 12),
                ),
                value: syncState.wifiOnly,
                activeColor: AppTheme.obsidianPill,
                onChanged: notifier.toggleWifiOnly,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                  'Skip already backed-up files (SHA-256)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Verify cryptographic file digest before uploading',
                  style: TextStyle(fontSize: 12),
                ),
                value: syncState.skipDuplicates,
                activeColor: AppTheme.obsidianPill,
                onChanged: notifier.toggleSkipDuplicates,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Watched Folders & Albums',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.defaultInternalFolders.take(8).map((folder) {
            final selected = syncState.selectedAlbums.contains(folder);
            return FilterChip(
              selected: selected,
              label: Text(folder),
              selectedColor: AppTheme.obsidianPill,
              checkmarkColor: Colors.white,
              backgroundColor: AppTheme.surfaceCard,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              onSelected: (_) => notifier.toggleAlbumSelection(folder),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upload Queue & History (${syncState.queue.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            if (syncState.queue.isNotEmpty)
              TextButton(
                onPressed: notifier.clearCompletedHistory,
                child: const Text('Clear completed'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (syncState.queue.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_Queue_rounded,
                    size: 36, color: AppTheme.textMuted),
                SizedBox(height: 10),
                Text(
                  'Upload queue is empty',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap "Sync Now" above or select files in the Files tab to back them up to your Telegram Saved Messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          )
        else
          ...syncState.queue.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                      Icon(
                        _statusIcon(item.status),
                        color: _statusColor(item.status),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${item.folderName} • ${FormatUtils.formatBytes(item.sizeBytes)} • ${item.status.label}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.status == UploadTaskStatus.pending ||
                          item.status == UploadTaskStatus.paused ||
                          item.status == UploadTaskStatus.failed)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => notifier.cancelTask(item.id),
                        ),
                    ],
                  ),
                  if (item.status == UploadTaskStatus.uploading) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 5,
                        backgroundColor: AppTheme.surfaceSubtle,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.telegramBlue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  IconData _statusIcon(UploadTaskStatus status) {
    switch (status) {
      case UploadTaskStatus.pending:
        return Icons.schedule_rounded;
      case UploadTaskStatus.uploading:
        return Icons.cloud_upload_rounded;
      case UploadTaskStatus.uploaded:
        return Icons.check_circle_rounded;
      case UploadTaskStatus.paused:
        return Icons.pause_circle_filled_rounded;
      case UploadTaskStatus.failed:
        return Icons.error_rounded;
      case UploadTaskStatus.skippedDuplicate:
        return Icons.verified_rounded;
    }
  }

  Color _statusColor(UploadTaskStatus status) {
    switch (status) {
      case UploadTaskStatus.pending:
        return AppTheme.textMuted;
      case UploadTaskStatus.uploading:
        return AppTheme.telegramBlue;
      case UploadTaskStatus.uploaded:
        return AppTheme.success;
      case UploadTaskStatus.paused:
        return AppTheme.warning;
      case UploadTaskStatus.failed:
        return AppTheme.danger;
      case UploadTaskStatus.skippedDuplicate:
        return AppTheme.dotVideos;
    }
  }
}

class _CloudMetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _CloudMetricPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textOnDarkMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

