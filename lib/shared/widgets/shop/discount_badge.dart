import 'package:base_project/app/theme/app_colors.dart';
import 'package:base_project/app/theme/app_radius.dart';
import 'package:flutter/material.dart';

/// Compact sale / promo badge for product surfaces.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.destructive,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
