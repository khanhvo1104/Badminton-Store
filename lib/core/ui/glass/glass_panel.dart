import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = AppSpacing.panel,
    this.margin,
    this.enableBlur = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      elevated: true,
      enableBlur: enableBlur,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
