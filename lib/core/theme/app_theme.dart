import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TeleVault Custom Design System
/// Keeps the exact layout structure and screen pace of the reference screenshots
/// while upgrading the visual aesthetic to a refined Warm Alabaster, Deep Obsidian
/// Slate, and Electric Indigo/Telegram Sky palette with elevated card geometry.
class AppTheme {
  AppTheme._();

  // Core Surfaces
  static const Color backgroundCanvas = Color(0xFFF3F2EE); // Warm Alabaster stone
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFEBE9E2);
  static const Color borderSubtle = Color(0xFFE2E0D8);

  // Hero Obsidian / Dark Surfaces
  static const Color obsidianCard = Color(0xFF10131A);
  static const Color obsidianElevated = Color(0xFF1B202C);
  static const Color obsidianPill = Color(0xFF12141C);

  // Brand & Semantic Accents
  static const Color telegramBlue = Color(0xFF3B7BFF);
  static const Color telegramSky = Color(0xFF5993FF);
  static const Color folderBlue = Color(0xFF4C82F7);
  static const Color folderTileBg = Color(0xFFF2F5FA);

  // Category Dot Accents
  static const Color dotImages = Color(0xFF16A34A); // Emerald green
  static const Color dotVideos = Color(0xFF8B5CF6); // Vivid purple
  static const Color dotAudio = Color(0xFFEA580C);  // Warm orange
  static const Color dotDocs = Color(0xFF2563EB);   // Royal blue
  static const Color dotApps = Color(0xFF0D9488);   // Teal

  // Text Colors
  static const Color textPrimary = Color(0xFF111318);
  static const Color textSecondary = Color(0xFF686B73);
  static const Color textMuted = Color(0xFF9497A1);
  static const Color textOnDark = Color(0xFFF9FAFB);
  static const Color textOnDarkMuted = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: telegramBlue,
        brightness: Brightness.light,
        primary: obsidianPill,
        secondary: telegramBlue,
        surface: surfaceCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundCanvas,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: obsidianCard,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0EFEA),
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.9,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.7,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
      ),
    );
  }
}

