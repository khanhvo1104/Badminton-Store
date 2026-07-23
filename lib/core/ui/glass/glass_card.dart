import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

enum GlassCardVariant { normal, elevated, interactive, selected, disabled }

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.variant = GlassCardVariant.normal,
    this.onTap,
    this.padding = AppSpacing.card,
    this.margin,
  });

  final Widget child;
  final GlassCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final elevated =
        variant == GlassCardVariant.elevated ||
        variant == GlassCardVariant.selected ||
        variant == GlassCardVariant.interactive;

    return Opacity(
      opacity: variant == GlassCardVariant.disabled ? 0.55 : 1,
      child: LiquidGlassContainer(
        // List-safe: no per-item blur; parent screens provide ambient glass.
        enableBlur: false,
        elevated: elevated,
        showHighlight: variant != GlassCardVariant.disabled,
        padding: padding,
        margin: margin,
        onTap: variant == GlassCardVariant.disabled ? null : onTap,
        enabled: variant != GlassCardVariant.disabled,
        child: child,
      ),
    );
  }
}
