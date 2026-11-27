import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely load environment configuration if present (.env or .env.example fallback)
  try {
    await dotenv.load(fileName: '.env.example');
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: TeleVaultApp(),
    ),
  );
}

class TeleVaultApp extends StatelessWidget {
  const TeleVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}

