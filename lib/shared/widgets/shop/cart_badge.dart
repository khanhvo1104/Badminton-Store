import 'package:base_project/core/ui/glass/glass_icon_button.dart';
import 'package:flutter/material.dart';

/// Cart icon with optional item-count badge.
class CartBadge extends StatelessWidget {
  const CartBadge({super.key, this.count = 0, this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.shopping_bag_outlined,
      tooltip: 'Cart',
      badgeCount: count > 0 ? count : null,
      onPressed: onPressed,
    );
  }
}
