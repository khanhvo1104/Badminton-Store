import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/core/ui/glass/glass_theme_data.dart';
import 'package:base_project/core/ui/glass/glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlassQuality', () {
    test('defaults to medium from unknown storage', () {
      expect(GlassQuality.fromStorage(null), GlassQuality.medium);
      expect(GlassQuality.fromStorage('nope'), GlassQuality.medium);
    });

    test('parses known values', () {
      expect(GlassQuality.fromStorage('high'), GlassQuality.high);
      expect(GlassQuality.fromStorage('disabled'), GlassQuality.disabled);
    });
  });

  group('GlassThemeData tokens', () {
    test('light medium enables blur', () {
      final theme = GlassThemeData.light();
      expect(theme.blurEnabled, isTrue);
      expect(theme.blurSigma, greaterThan(0));
      expect(theme.surfaceOpacity, lessThan(1));
    });

    test('dark medium enables blur', () {
      final theme = GlassThemeData.dark();
      expect(theme.blurEnabled, isTrue);
      expect(theme.surfaceOpacity, lessThan(1));
    });

    test('disabled quality removes blur and raises opacity', () {
      final theme = GlassThemeData.light(quality: GlassQuality.disabled);
      expect(theme.blurEnabled, isFalse);
      expect(theme.blurSigma, 0);
      expect(theme.surfaceOpacity, greaterThan(0.9));
    });

    test('low quality reduces blur versus medium', () {
      final medium = GlassThemeData.light();
      final low = GlassThemeData.light(quality: GlassQuality.low);
      expect(low.blurSigma, lessThan(medium.blurSigma));
    });

    test('high quality enables animated highlights', () {
      final medium = GlassThemeData.light();
      final high = GlassThemeData.light(quality: GlassQuality.high);
      expect(medium.animatedHighlights, isFalse);
      expect(high.animatedHighlights, isTrue);
    });

    test('lerp interpolates opacity', () {
      final a = GlassThemeData.light();
      final b = GlassThemeData.dark();
      final mid = a.lerp(b, 0.5);
      expect(mid.surfaceOpacity, isA<double>());
    });

    test('GlassTokens forBrightness', () {
      final light = GlassTokens.forBrightness(Brightness.light);
      final dark = GlassTokens.forBrightness(Brightness.dark);
      expect(light.blurSigma, isNonZero);
      expect(dark.blurSigma, isNonZero);
    });
  });
}
