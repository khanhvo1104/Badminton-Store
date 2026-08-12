import 'package:base_project/core/constants/currency_constants.dart';
import 'package:base_project/shared/widgets/shop/product_card_layout.dart';
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
    this.wrap = false,
  });

  final int amount;
  final int? compareAtAmount;
  final String currencyCode;
  final bool compact;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = formatAmount(amount, currencyCode);
    final hasDiscount = compareAtAmount != null && compareAtAmount! > amount;

    final amountStyle = wrap
        ? ProductCardLayout.priceStyle(
            theme.textTheme,
            compact: compact,
          ).copyWith(color: theme.colorScheme.primary)
        : (compact ? theme.textTheme.labelLarge : theme.textTheme.titleMedium)
              ?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              );
    final compareAtStyle = wrap
        ? ProductCardLayout.compareAtStyle(
            theme.textTheme,
          ).copyWith(color: theme.colorScheme.onSurfaceVariant)
        : theme.textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant,
          );

    final amountText = Text(formatted, style: amountStyle);
    final compareAtText = hasDiscount
        ? Text(
            formatAmount(compareAtAmount!, currencyCode),
            style: compareAtStyle,
          )
        : null;

    if (wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [amountText, if (compareAtText != null) compareAtText],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        amountText,
        if (compareAtText != null) ...[const SizedBox(width: 8), compareAtText],
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
