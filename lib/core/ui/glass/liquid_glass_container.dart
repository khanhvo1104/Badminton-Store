import 'dart:ui';

import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/core/ui/glass/glass_highlight_painter.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/core/ui/glass/glass_theme.dart';
import 'package:flutter/material.dart';

/// Controlled Liquid Glass surface. Prefer one shared blur parent over
/// per-item BackdropFilter in long lists.
class LiquidGlassContainer extends StatefulWidget {
  const LiquidGlassContainer({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.blurStrength,
    this.backgroundOpacity,
    this.borderColor,
    this.borderWidth,
    this.gradient,
    this.shadow,
    this.showHighlight = true,
    this.elevated = false,
    this.enableBlur = true,
    this.onTap,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
    this.qualityOverride,
    this.enabled = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double? blurStrength;
  final double? backgroundOpacity;
  final Color? borderColor;
  final double? borderWidth;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final bool showHighlight;
  final bool elevated;
  final bool enableBlur;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Clip clipBehavior;
  final GlassQuality? qualityOverride;
  final bool enabled;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSheen();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSheen();
  }

  void _syncSheen() {
    final glass = context.glassTheme;
    final quality = widget.qualityOverride;
    final highQuality =
        quality == GlassQuality.high ||
        (quality == null && glass.animatedHighlights);
    final allowSheen =
        AppMotion.allowContinuousMotion(context) &&
        widget.showHighlight &&
        widget.enableBlur &&
        glass.blurEnabled &&
        highQuality;

    if (allowSheen) {
      if (!_sheenController.isAnimating) {
        _sheenController.repeat(reverse: true);
      }
    } else {
      _sheenController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final radius =
        widget.borderRadius ??
        BorderRadius.circular(
          widget.elevated ? glass.cardRadius : glass.controlRadius,
        );
    final opacity =
        widget.backgroundOpacity ??
        (widget.elevated ? glass.elevatedSurfaceOpacity : glass.surfaceOpacity);
    final blur = widget.enableBlur && glass.blurEnabled
        ? (widget.blurStrength ??
              (widget.elevated ? glass.strongBlurSigma : glass.blurSigma))
        : 0.0;
    final borderColor =
        widget.borderColor ??
        (widget.elevated ? glass.strongBorderColor : glass.borderColor);
    final borderWidth = widget.borderWidth ?? glass.borderWidth;
    final shadows =
        widget.shadow ??
        [
          BoxShadow(
            color: glass.shadowColor,
            blurRadius: glass.shadowBlurRadius * (_pressed ? 0.6 : 1),
            offset: glass.shadowOffset * (_pressed ? 0.6 : 1),
          ),
        ];

    Widget content = AnimatedBuilder(
      animation: _sheenController,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: widget.showHighlight
              ? GlassHighlightPainter(
                  highlightColor: glass.highlightColor,
                  reflectionColor: glass.reflectionColor,
                  radius: radius.topLeft.x,
                  highlightWidth: glass.highlightWidth,
                  progress: _sheenController.value,
                )
              : null,
          child: child,
        );
      },
      child: Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: widget.child,
      ),
    );

    if (blur > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      );
    }

    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color:
            (widget.elevated ? glass.elevatedSurfaceColor : glass.surfaceColor)
                .withValues(alpha: opacity),
        gradient: widget.gradient,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: content,
    );

    content = ClipRRect(
      borderRadius: radius,
      clipBehavior: widget.clipBehavior,
      child: content,
    );

    if (widget.onTap != null && widget.enabled) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.standardCurve,
            child: content,
          ),
        ),
      );
    }

    return Semantics(
      button: widget.onTap != null,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: content,
        ),
      ),
    );
  }
}

/// Alias matching the requested design-system naming.
typedef GlassSurface = LiquidGlassContainer;
