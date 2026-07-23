import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.selected = false,
    this.badgeCount,
    this.isLoading = false,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final int? badgeCount;
  final bool isLoading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = LiquidGlassContainer(
      enableBlur: false,
      elevated: selected,
      width: 48,
      height: 48,
      padding: EdgeInsets.zero,
      onTap: isLoading ? null : onPressed,
      enabled: onPressed != null && !isLoading,
      semanticLabel: semanticLabel ?? tooltip,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Badge(
                isLabelVisible: badgeCount != null && badgeCount! > 0,
                label: Text('${badgeCount ?? 0}'),
                child: Icon(icon),
              ),
      ),
    );

    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }
}
