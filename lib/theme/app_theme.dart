import 'package:flutter/material.dart';

/// Central definitions for colors used throughout the app
class AppColors {
  /// Primary brand blue
  static const Color primary = Color(0xFF1A73E8);

  /// Lighter companion blue for gradients, accents, etc.
  static const Color light = Color(0xFF2FA7ED);
}

/// Main theme configuration for the application
class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,

    // Color scheme generated from seed + overrides
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.primary,
      onPrimary: Colors.white,
    ),

    // Floating action button style
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(100)),
      ),
      sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
    ),

    // Card theme
    cardTheme: CardTheme(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
    ),

    // You can add more theming here: textTheme, inputDecorationTheme, etc.
  );
}
