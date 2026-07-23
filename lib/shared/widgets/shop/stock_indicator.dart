import 'package:base_project/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Lightweight stock status text for product cards and detail.
class StockIndicator extends StatelessWidget {
  const StockIndicator({
    required this.quantity,
    super.key,
    this.lowStockThreshold = 5,
  });

  final int quantity;
  final int lowStockThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (quantity) {
      <= 0 => ('Out of stock', AppColors.destructive),
      final q when q <= lowStockThreshold => (
        'Only $q left',
        theme.colorScheme.tertiary,
      ),
      _ => ('In stock', AppColors.success),
    };

    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
