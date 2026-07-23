import 'package:base_project/core/constants/currency_constants.dart';
import 'package:flutter/material.dart';

/// Formats money amounts for shop surfaces.
///
/// Expects [amount] in minor units for [currencyCode].
class PriceLabel extends StatelessWidget {
  const PriceLabel({
    required this.amount,
    super.key,
    this.compareAtAmount,
    this.currencyCode = CurrencyConstants.defaultCurrencyCode,
    this.compact = false,
  });

  final int amount;
  final int? compareAtAmount;
  final String currencyCode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = formatAmount(amount, currencyCode);
    final hasDiscount = compareAtAmount != null && compareAtAmount! > amount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatted,
          style:
              (compact
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.titleMedium)
                  ?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 8),
          Text(
            formatAmount(compareAtAmount!, currencyCode),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  static String formatAmount(int amount, String currencyCode) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    if (currencyCode == CurrencyConstants.defaultCurrencyCode) {
      return '$buffer${CurrencyConstants.defaultCurrencySymbol}';
    }
    return '$buffer $currencyCode';
  }
}
