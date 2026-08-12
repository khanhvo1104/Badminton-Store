import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/shared/widgets/shop/product_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Responsive 2-column ProductCard grid used by Catalog, Search, and Favorites.
class ProductCardGridView extends StatelessWidget {
  const ProductCardGridView({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      gridDelegate: ProductCardGridDelegate.fromContext(context),
      itemBuilder: itemBuilder,
    );
  }
}

/// Sizes each tile from the actual cross-axis width and text scale.
class ProductCardGridDelegate extends SliverGridDelegate {
  const ProductCardGridDelegate({
    required this.textScaler,
    required this.textTheme,
    this.crossAxisCount = ProductCardLayout.gridCrossAxisCount,
    this.crossAxisSpacing = ProductCardLayout.gridSpacing,
    this.mainAxisSpacing = ProductCardLayout.gridSpacing,
    this.cardPadding = AppSpacing.card,
  });

  factory ProductCardGridDelegate.fromContext(BuildContext context) {
    return ProductCardGridDelegate(
      textScaler: MediaQuery.textScalerOf(context),
      textTheme: Theme.of(context).textTheme,
    );
  }

  final TextScaler textScaler;
  final TextTheme textTheme;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry cardPadding;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usableCrossAxisExtent = ProductCardLayout.nonNegative(
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final childMainAxisExtent = ProductCardLayout.mainAxisExtent(
      cardWidth: childCrossAxisExtent,
      textScaler: textScaler,
      textTheme: textTheme,
      padding: cardPadding,
    );

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant ProductCardGridDelegate oldDelegate) {
    return oldDelegate.textScaler != textScaler ||
        oldDelegate.textTheme != textTheme ||
        oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.cardPadding != cardPadding;
  }
}
