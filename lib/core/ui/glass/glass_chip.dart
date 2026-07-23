import 'package:base_project/app/theme/app_radius.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

class GlassChip extends StatelessWidget {
  const GlassChip({
    required this.label,
    super.key,
    this.selected = false,
    this.enabled = true,
    this.icon,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: LiquidGlassContainer(
        enableBlur: false,
        elevated: selected,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: enabled ? onTap : null,
        enabled: enabled,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 6),
            ],
            Text(label),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: enabled ? onDeleted : null,
                child: const Icon(Icons.close, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
