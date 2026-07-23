import 'package:base_project/core/ui/glass/glass_theme_data.dart';
import 'package:flutter/material.dart';

extension GlassThemeContext on BuildContext {
  GlassThemeData get glassTheme {
    final theme = Theme.of(this).extension<GlassThemeData>();
    assert(theme != null, 'GlassThemeData is not registered on ThemeData');
    return theme!;
  }

  ColorScheme get appColors => Theme.of(this).colorScheme;

  TextTheme get appTypography => Theme.of(this).textTheme;
}
