import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Opens the interactive Phone Number -> OTP -> 2FA login modal sheet.
Future<void> showTelegramAuthModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const TelegramAuthSheet(),
  );
}

class TelegramAuthSheet extends ConsumerStatefulWidget {
  const TelegramAuthSheet({super.key});

  @override
  ConsumerState<TelegramAuthSheet> createState() => _TelegramAuthSheetState();
}

class _TelegramAuthSheetState extends ConsumerState<TelegramAuthSheet> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _twoFactorCtrl = TextEditingController();
  bool _obscure2FA = true;

  static const List<Map<String, String>> _countryCodes = [
    {'code': '+880', 'label': 'BD (+880)'},
    {'code': '+1', 'label': 'US (+1)'},
    {'code': '+44', 'label': 'UK (+44)'},
    {'code': '+91', 'label': 'IN (+91)'},
    {'code': '+971', 'label': 'UAE (+971)'},
    {'code': '+65', 'label': 'SG (+65)'},
    {'code': '+49', 'label': 'DE (+49)'},
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _twoFactorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset + 28),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppTheme.telegramBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect Telegram Cloud',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        authState.isDemoMode
                            ? 'MTProto Client Bridge • Simulation Mode Active'
                            : 'MTProto Bridge: ${authState.bridgeUrl}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Bridge Settings',
                  onPressed: () => _showBridgeConfigDialog(context),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mandatory Security & Privacy Notice Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFB45309),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.securityWarningTitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          AppConstants.securityWarningBody,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF92400E),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (authState.errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  authState.errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (authState.step == AuthFlowStep.phoneInput)
              _buildPhoneStep(context, authState)
            else if (authState.step == AuthFlowStep.otpInput)
              _buildOtpStep(context, authState)
            else if (authState.step == AuthFlowStep.twoFactorInput)
              _buildTwoFactorStep(context, authState)
            else
              _buildConnectedStep(context, authState),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1 of 2 • Enter your Telegram phone number',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Telegram will send a 5-digit login code directly to your Telegram app or via SMS.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: authState.countryCode,
                  items: _countryCodes
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['code'],
                          child: Text(
                            c['label']!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(authProvider.notifier).setCountryCode(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '1712 345678',
                  filled: true,
                  fillColor: AppTheme.surfaceCard,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: authState.isLoading
                ? null
                : () async {
                    await ref
                        .read(authProvider.notifier)
                        .sendOtpCode(_phoneCtrl.text);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.obsidianPill,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: authState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              authState.isLoading ? 'Sending OTP...' : 'Send Login Code',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(BuildContext context, AuthState authState) {
    final fullPhone = '${authState.countryCode} ${authState.phoneNumber}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Step 2 of 2 • Enter code sent to $fullPhone',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(authProvider.notifier).backToPhoneInput(),
              child: const Text('Change number'),
            ),
          ],
        ),
        if (authState.isDemoMode)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Demo Tip: Enter any 5-digit code (e.g. 12345) to sign in immediately, or enter 22222 to test the Two-Step Verification (2FA) password prompt.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.telegramBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '1 2 3 4 5',
            filled: true,
            fillColor: AppTheme.surfaceCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              authState.resendSecondsRemaining > 0
                  ? 'Resend code in ${authState.resendSecondsRemaining}s'
                  : 'Didn\'t receive the code?',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textMuted,
              ),
            ),
            if (authState.resendSecondsRemaining == 0)
              TextButton(
                onPressed: () => ref
                    .read(authProvider.notifier)
                    .sendOtpCode(authState.phoneNumber),
                child: const Text('Resend OTP'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: authState.isLoading
                ? null
                : () async {
                    final ok = await ref
                        .read(authProvider.notifier)
                        .verifyOtpCode(_otpCtrl.text);
                    if (ok &&
                        mounted &&
                        ref.read(authProvider).step ==
                            AuthFlowStep.authenticated) {
                      Navigator.of(context).pop();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.obsidianPill,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: Text(
              authState.isLoading ? 'Verifying...' : 'Verify & Connect',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoFactorStep(BuildContext context, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Two-Step Verification Required',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Telegram account is protected with a Cloud Password. Enter it below to complete authentication.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _twoFactorCtrl,
          obscureText: _obscure2FA,
          decoration: InputDecoration(
            hintText: 'Enter Telegram 2FA Cloud Password',
            filled: true,
            fillColor: AppTheme.surfaceCard,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure2FA
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _obscure2FA = !_obscure2FA),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: authState.isLoading
                ? null
                : () async {
                    final ok = await ref
                        .read(authProvider.notifier)
                        .verifyTwoFactorPassword(_twoFactorCtrl.text);
                    if (ok && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.obsidianPill,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: Text(
              authState.isLoading
                  ? 'Unlocking Session...'
                  : 'Unlock with 2FA Password',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedStep(BuildContext context, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.connectedUsername ?? 'Connected to Telegram',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Destination: Saved Messages (Private Cloud)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).disconnectTelegram();
              if (mounted) Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Disconnect Telegram Account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showBridgeConfigDialog(BuildContext context) async {
    final authState = ref.read(authProvider);
    final urlCtrl = TextEditingController(text: authState.bridgeUrl);
    var demoMode = authState.isDemoMode;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text(
                'MTProto Bridge Config',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Never hardcode api_id or api_hash in Flutter client code. Point TeleVault to your MTProto bridge endpoint or use Simulation Mode.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Bridge Base URL',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Offline Demo / Simulation Mode',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Simulates Phone -> OTP -> 2FA & chunked uploads locally',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    value: demoMode,
                    onChanged: (v) => setDialogState(() => demoMode = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).updateBridgeConfig(
                          bridgeUrl: urlCtrl.text,
                          isDemoMode: demoMode,
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

