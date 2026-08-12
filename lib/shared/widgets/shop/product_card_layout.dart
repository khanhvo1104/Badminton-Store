import 'package:base_project/app/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shared ProductCard geometry used by storefront grids.
///
/// Keeps Catalog, Search, and Favorites on one responsive sizing strategy
/// instead of drifting `childAspectRatio` copies.
abstract final class ProductCardLayout {
  static const int titleMaxLines = 2;
  static const int priceMaxLines = 2;
  static const double gridSpacing = 12;
  static const int gridCrossAxisCount = 2;
  static const double priceRunSpacing = 2;
  static const double mediaAspectRatio = 1;
  static const double titleLineHeight = 1.43;
  static const double priceLineHeight = 1.4;
  static const double stockLineHeight = 1.45;

  static TextStyle titleStyle(TextTheme textTheme) {
    final base = textTheme.titleSmall;
    return (base ?? const TextStyle(fontSize: 14)).copyWith(
      inherit: false,
      fontSize: base?.fontSize ?? 14,
      height: titleLineHeight,
      fontWeight: base?.fontWeight,
      letterSpacing: base?.letterSpacing,
      color: base?.color,
    );
  }

  static TextStyle priceStyle(TextTheme textTheme, {required bool compact}) {
    final base = compact ? textTheme.labelLarge : textTheme.titleMedium;
    return (base ?? const TextStyle(fontSize: 16)).copyWith(
      inherit: false,
      fontSize: base?.fontSize ?? 16,
      height: priceLineHeight,
      fontWeight: FontWeight.w700,
      color: base?.color,
    );
  }

  static TextStyle compareAtStyle(TextTheme textTheme) {
    final base = textTheme.bodySmall;
    return (base ?? const TextStyle(fontSize: 12)).copyWith(
      inherit: false,
      fontSize: base?.fontSize ?? 12,
      height: priceLineHeight,
      decoration: TextDecoration.lineThrough,
      color: base?.color,
    );
  }

  static double nonNegative(double value) => value < 0 ? 0 : value;

  static double paintedHeight({
    required String text,
    required TextStyle style,
    required TextScaler textScaler,
    required double maxWidth,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: nonNegative(maxWidth));
    return painter.height;
  }

  /// Vertical space a card needs for a square image plus measured 2-line
  /// title, wrapped price/compare-at, and wrapping stock at the current scale.
  static double mainAxisExtent({
    required double cardWidth,
    required TextScaler textScaler,
    required TextTheme textTheme,
    EdgeInsetsGeometry padding = AppSpacing.card,
  }) {
    final resolved = padding.resolve(TextDirection.ltr);
    final contentWidth = nonNegative(cardWidth - resolved.horizontal);
    final titleHeight = paintedHeight(
      text:
          'Vợt cầu lông Yonex Astrox 99 Pro Limited Edition Championship Series',
      style: titleStyle(textTheme),
      textScaler: textScaler,
      maxWidth: contentWidth,
      maxLines: titleMaxLines,
    );
    final amountHeight = paintedHeight(
      text: '12.345.678₫',
      style: priceStyle(textTheme, compact: false),
      textScaler: textScaler,
      maxWidth: contentWidth,
      maxLines: priceMaxLines,
    );
    final compareHeight = paintedHeight(
      text: '12.345.678₫',
      style: compareAtStyle(textTheme),
      textScaler: textScaler,
      maxWidth: contentWidth,
      maxLines: priceMaxLines,
    );
    final stockHeight = paintedHeight(
      text: 'Only 99 left',
      style: (textTheme.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(
        inherit: false,
        fontSize: textTheme.labelSmall?.fontSize ?? 11,
        height: stockLineHeight,
        fontWeight: FontWeight.w600,
      ),
      textScaler: textScaler,
      maxWidth: contentWidth,
    );

    final mediaExtent = contentWidth / mediaAspectRatio;

    return resolved.vertical +
        mediaExtent +
        AppSpacing.sm +
        titleHeight +
        AppSpacing.xs +
        amountHeight +
        priceRunSpacing +
        compareHeight +
        AppSpacing.xs +
        stockHeight;
  }
}
