import 'package:base_project/core/ui/glass/glass_chip.dart';
import 'package:flutter/material.dart';

/// Brand filter chip built on [GlassChip].
class BrandChip extends StatelessWidget {
  const BrandChip({
    required this.label,
    super.key,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassChip(
      label: label,
      selected: selected,
      icon: Icons.storefront_outlined,
      onTap: onTap,
    );
  }
}
