import 'package:base_project/app/theme/app_colors.dart';
import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/app/theme/app_radius.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:flutter/material.dart';

@immutable
class GlassThemeData extends ThemeExtension<GlassThemeData> {
  const GlassThemeData({
    required this.backgroundGradient,
    required this.backgroundOverlay,
    required this.surfaceColor,
    required this.elevatedSurfaceColor,
    required this.borderColor,
    required this.strongBorderColor,
    required this.highlightColor,
    required this.reflectionColor,
    required this.shadowColor,
    required this.accentGlowColor,
    required this.blurSigma,
    required this.strongBlurSigma,
    required this.backgroundBlurSigma,
    required this.surfaceOpacity,
    required this.elevatedSurfaceOpacity,
    required this.borderWidth,
    required this.highlightWidth,
    required this.shadowBlurRadius,
    required this.shadowOffset,
    required this.cardRadius,
    required this.controlRadius,
    required this.animationDuration,
    required this.animationCurve,
    this.animatedHighlights = false,
  });

  factory GlassThemeData.light({GlassQuality quality = GlassQuality.medium}) {
    return _resolve(
      quality: quality,
      base: const GlassThemeData(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8FFF8), Color(0xFFE0F7FF), Color(0xFFFFF6E8)],
        ),
        backgroundOverlay: Color(0x22FFFFFF),
        surfaceColor: AppColors.glassTintLight,
        elevatedSurfaceColor: Color(0xFAFFFFFF),
        borderColor: Color(0x88FFFFFF),
        strongBorderColor: Color(0xB3FFFFFF),
        highlightColor: Color(0xE6FFFFFF),
        reflectionColor: Color(0x66FFFFFF),
        shadowColor: Color(0x2200B894),
        accentGlowColor: Color(0x4400B894),
        blurSigma: 18,
        strongBlurSigma: 28,
        backgroundBlurSigma: 40,
        surfaceOpacity: 0.72,
        elevatedSurfaceOpacity: 0.86,
        borderWidth: 1,
        highlightWidth: 1.2,
        shadowBlurRadius: 24,
        shadowOffset: Offset(0, 10),
        cardRadius: AppRadius.lg,
        controlRadius: AppRadius.md,
        animationDuration: AppMotion.standard,
        animationCurve: Curves.easeOutCubic,
      ),
    );
  }

  factory GlassThemeData.dark({GlassQuality quality = GlassQuality.medium}) {
    return _resolve(
      quality: quality,
      base: const GlassThemeData(
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1210), Color(0xFF12201B), Color(0xFF0E1A24)],
        ),
        backgroundOverlay: Color(0x22000000),
        surfaceColor: AppColors.glassTintDark,
        elevatedSurfaceColor: Color(0xE61F2C27),
        borderColor: Color(0x44FFFFFF),
        strongBorderColor: Color(0x66FFFFFF),
        highlightColor: Color(0x55FFFFFF),
        reflectionColor: Color(0x33FFFFFF),
        shadowColor: Color(0x66000000),
        accentGlowColor: Color(0x443DDC97),
        blurSigma: 20,
        strongBlurSigma: 32,
        backgroundBlurSigma: 48,
        surfaceOpacity: 0.55,
        elevatedSurfaceOpacity: 0.72,
        borderWidth: 1,
        highlightWidth: 1.1,
        shadowBlurRadius: 28,
        shadowOffset: Offset(0, 12),
        cardRadius: AppRadius.lg,
        controlRadius: AppRadius.md,
        animationDuration: AppMotion.standard,
        animationCurve: Curves.easeOutCubic,
      ),
    );
  }

  static GlassThemeData _resolve({
    required GlassQuality quality,
    required GlassThemeData base,
  }) {
    final resolved = switch (quality) {
      GlassQuality.disabled => base.copyWith(
        blurSigma: 0,
        strongBlurSigma: 0,
        backgroundBlurSigma: 0,
        surfaceOpacity: 0.96,
        elevatedSurfaceOpacity: 0.98,
        shadowBlurRadius: 8,
        highlightWidth: 0.8,
      ),
      GlassQuality.low => base.copyWith(
        blurSigma: base.blurSigma * 0.45,
        strongBlurSigma: base.strongBlurSigma * 0.45,
        backgroundBlurSigma: base.backgroundBlurSigma * 0.4,
        shadowBlurRadius: base.shadowBlurRadius * 0.5,
        surfaceOpacity: (base.surfaceOpacity + 0.18).clamp(0.0, 1.0),
      ),
      GlassQuality.medium => base,
      GlassQuality.high => base.copyWith(
        blurSigma: base.blurSigma * 1.15,
        strongBlurSigma: base.strongBlurSigma * 1.15,
        backgroundBlurSigma: base.backgroundBlurSigma * 1.1,
      ),
    };
    return resolved.copyWith(animatedHighlights: quality == GlassQuality.high);
  }

  final Gradient backgroundGradient;
  final Color backgroundOverlay;
  final Color surfaceColor;
  final Color elevatedSurfaceColor;
  final Color borderColor;
  final Color strongBorderColor;
  final Color highlightColor;
  final Color reflectionColor;
  final Color shadowColor;
  final Color accentGlowColor;
  final double blurSigma;
  final double strongBlurSigma;
  final double backgroundBlurSigma;
  final double surfaceOpacity;
  final double elevatedSurfaceOpacity;
  final double borderWidth;
  final double highlightWidth;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final double cardRadius;
  final double controlRadius;
  final Duration animationDuration;
  final Curve animationCurve;

  /// Continuous reflection sheen — only enabled at [GlassQuality.high].
  final bool animatedHighlights;

  bool get blurEnabled => blurSigma > 0;

  @override
  GlassThemeData copyWith({
    Gradient? backgroundGradient,
    Color? backgroundOverlay,
    Color? surfaceColor,
    Color? elevatedSurfaceColor,
    Color? borderColor,
    Color? strongBorderColor,
    Color? highlightColor,
    Color? reflectionColor,
    Color? shadowColor,
    Color? accentGlowColor,
    double? blurSigma,
    double? strongBlurSigma,
    double? backgroundBlurSigma,
    double? surfaceOpacity,
    double? elevatedSurfaceOpacity,
    double? borderWidth,
    double? highlightWidth,
    double? shadowBlurRadius,
    Offset? shadowOffset,
    double? cardRadius,
    double? controlRadius,
    Duration? animationDuration,
    Curve? animationCurve,
    bool? animatedHighlights,
  }) {
    return GlassThemeData(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      backgroundOverlay: backgroundOverlay ?? this.backgroundOverlay,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      elevatedSurfaceColor: elevatedSurfaceColor ?? this.elevatedSurfaceColor,
      borderColor: borderColor ?? this.borderColor,
      strongBorderColor: strongBorderColor ?? this.strongBorderColor,
      highlightColor: highlightColor ?? this.highlightColor,
      reflectionColor: reflectionColor ?? this.reflectionColor,
      shadowColor: shadowColor ?? this.shadowColor,
      accentGlowColor: accentGlowColor ?? this.accentGlowColor,
      blurSigma: blurSigma ?? this.blurSigma,
      strongBlurSigma: strongBlurSigma ?? this.strongBlurSigma,
      backgroundBlurSigma: backgroundBlurSigma ?? this.backgroundBlurSigma,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      elevatedSurfaceOpacity:
          elevatedSurfaceOpacity ?? this.elevatedSurfaceOpacity,
      borderWidth: borderWidth ?? this.borderWidth,
      highlightWidth: highlightWidth ?? this.highlightWidth,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      animatedHighlights: animatedHighlights ?? this.animatedHighlights,
    );
  }

  @override
  GlassThemeData lerp(ThemeExtension<GlassThemeData>? other, double t) {
    if (other is! GlassThemeData) {
      return this;
    }

    return GlassThemeData(
      backgroundGradient:
          Gradient.lerp(backgroundGradient, other.backgroundGradient, t) ??
          backgroundGradient,
      backgroundOverlay: Color.lerp(
        backgroundOverlay,
        other.backgroundOverlay,
        t,
      )!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      elevatedSurfaceColor: Color.lerp(
        elevatedSurfaceColor,
        other.elevatedSurfaceColor,
        t,
      )!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      strongBorderColor: Color.lerp(
        strongBorderColor,
        other.strongBorderColor,
        t,
      )!,
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t)!,
      reflectionColor: Color.lerp(reflectionColor, other.reflectionColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      accentGlowColor: Color.lerp(accentGlowColor, other.accentGlowColor, t)!,
      blurSigma: _lerpDouble(blurSigma, other.blurSigma, t),
      strongBlurSigma: _lerpDouble(strongBlurSigma, other.strongBlurSigma, t),
      backgroundBlurSigma: _lerpDouble(
        backgroundBlurSigma,
        other.backgroundBlurSigma,
        t,
      ),
      surfaceOpacity: _lerpDouble(surfaceOpacity, other.surfaceOpacity, t),
      elevatedSurfaceOpacity: _lerpDouble(
        elevatedSurfaceOpacity,
        other.elevatedSurfaceOpacity,
        t,
      ),
      borderWidth: _lerpDouble(borderWidth, other.borderWidth, t),
      highlightWidth: _lerpDouble(highlightWidth, other.highlightWidth, t),
      shadowBlurRadius: _lerpDouble(
        shadowBlurRadius,
        other.shadowBlurRadius,
        t,
      ),
      shadowOffset: Offset.lerp(shadowOffset, other.shadowOffset, t)!,
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      controlRadius: _lerpDouble(controlRadius, other.controlRadius, t),
      animationDuration: t < 0.5 ? animationDuration : other.animationDuration,
      animationCurve: t < 0.5 ? animationCurve : other.animationCurve,
      animatedHighlights: t < 0.5
          ? animatedHighlights
          : other.animatedHighlights,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
