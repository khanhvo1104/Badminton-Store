import 'package:base_project/app/theme/app_colors.dart';
import 'package:base_project/app/theme/app_radius.dart';
import 'package:base_project/app/theme/app_typography.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/core/ui/glass/glass_theme_data.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light({GlassQuality quality = GlassQuality.medium}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedLight,
      brightness: Brightness.light,
      surface: AppColors.surfaceTintLight,
      primary: AppColors.seedLight,
      onPrimary: Colors.white,
      secondary: AppColors.accentLight,
      onSecondary: Colors.white,
      tertiary: const Color(0xFF54A0FF),
      onTertiary: Colors.white,
      primaryContainer: const Color(0xFFD4FFF3),
      onPrimaryContainer: const Color(0xFF005C45),
      secondaryContainer: const Color(0xFFC8F7E8),
      onSecondaryContainer: const Color(0xFF005C45),
      tertiaryContainer: const Color(0xFFDCECFF),
      onTertiaryContainer: const Color(0xFF0A3D7A),
    );
    return _base(
      colorScheme,
      Brightness.light,
      GlassThemeData.light(quality: quality),
    );
  }

  /// The storefront is deliberately light. Host dark appearance (and the
  /// settings "dark" preference) must not switch child screens onto black
  /// scaffolds or dark-on-black text.
  static ThemeData dark({GlassQuality quality = GlassQuality.medium}) {
    return light(quality: quality);
  }

  static ThemeData _base(
    ColorScheme colorScheme,
    Brightness brightness,
    GlassThemeData glass,
  ) {
    final textTheme = AppTypography.textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      // Solid mint/off-white fallback for routes that are not wrapped in
      // [GlassBackground]. Shell pages that want the ambient gradient still
      // set Scaffold.backgroundColor to Colors.transparent explicitly.
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: [glass],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: glass.elevatedSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(glass.cardRadius),
          side: BorderSide(color: glass.borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass.surfaceColor.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: glass.elevatedSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(glass.cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: glass.elevatedSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(glass.cardRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
    );
  }
}
