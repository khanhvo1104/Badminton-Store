import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/core/ui/glass/glass_theme_data.dart';
import 'package:flutter/material.dart';

/// Resolved runtime tokens for a given quality.
abstract final class GlassTokens {
  static GlassThemeData forBrightness(
    Brightness brightness, {
    GlassQuality quality = GlassQuality.medium,
  }) {
    return brightness == Brightness.dark
        ? GlassThemeData.dark(quality: quality)
        : GlassThemeData.light(quality: quality);
  }
}
