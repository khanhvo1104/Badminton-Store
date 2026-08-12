import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/constants/image_sizes.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/shared/widgets/shop/discount_badge.dart';
import 'package:base_project/shared/widgets/shop/favorite_button.dart';
import 'package:base_project/shared/widgets/shop/price_label.dart';
import 'package:base_project/shared/widgets/shop/product_card_layout.dart';
import 'package:base_project/shared/widgets/shop/stock_indicator.dart';
import 'package:flutter/material.dart';

/// Reusable product tile shell. Content wiring arrives in a later milestone.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.title,
    required this.priceAmount,
    super.key,
    this.imageUrl,
    this.compareAtAmount,
    this.currencyCode = 'VND',
    this.isFavorite = false,
    this.stockQuantity,
    this.onTap,
    this.onFavoritePressed,
  });

  final String title;
  final String? imageUrl;
  final int priceAmount;
  final int? compareAtAmount;
  final String currencyCode;
  final bool isFavorite;
  final int? stockQuantity;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount =
        compareAtAmount != null && compareAtAmount! > priceAmount;
    final hasRenderableImage =
        imageUrl != null &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    final image = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: !hasRenderableImage
              ? Center(
                  child: FittedBox(
                    child: Icon(
                      Icons.sports_tennis,
                      size: ImageSizes.thumbnail,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
        if (hasDiscount)
          const Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: DiscountBadge(label: 'Sale'),
          ),
        Positioned(
          top: AppSpacing.xs,
          right: AppSpacing.xs,
          child: FavoriteButton(
            isFavorite: isFavorite,
            onPressed: onFavoritePressed == null
                ? null
                : () => onFavoritePressed!(!isFavorite),
          ),
        ),
      ],
    );

    return GlassCard(
      variant: GlassCardVariant.interactive,
      onTap: onTap,
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: ProductCardLayout.mediaAspectRatio,
            child: image,
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: title,
            child: ExcludeSemantics(
              child: Text(
                title,
                maxLines: ProductCardLayout.titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: ProductCardLayout.titleStyle(theme.textTheme),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          PriceLabel(
            amount: priceAmount,
            compareAtAmount: compareAtAmount,
            currencyCode: currencyCode,
            wrap: true,
          ),
          if (stockQuantity != null) ...[
            const SizedBox(height: AppSpacing.xs),
            StockIndicator(quantity: stockQuantity!),
          ],
        ],
      ),
    );
  }
}
