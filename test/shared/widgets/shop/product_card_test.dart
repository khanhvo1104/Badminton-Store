import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/shared/widgets/shop/favorite_button.dart';
import 'package:base_project/shared/widgets/shop/price_label.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:base_project/shared/widgets/shop/product_card_grid.dart';
import 'package:base_project/shared/widgets/shop/product_card_layout.dart';
import 'package:base_project/shared/widgets/shop/stock_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'product_card_test_support.dart';

void main() {
  test(
    'grid extent exceeds the legacy 0.58 aspect ratio at 320dp and 1.3 scale',
    () {
      const cardWidth =
          (320 - 32 - ProductCardLayout.gridSpacing) /
          ProductCardLayout.gridCrossAxisCount;
      const legacyHeight = cardWidth / 0.58;
      final extent = ProductCardLayout.mainAxisExtent(
        cardWidth: cardWidth,
        textScaler: const TextScaler.linear(1.3),
        textTheme: AppTheme.light().textTheme,
      );

      expect(extent, greaterThan(legacyHeight));
    },
  );

  testWidgets(
    'long Vietnamese title stays inside the card at 320dp and text scale 1.3',
    (tester) async {
      var tapped = false;
      var favorite = false;

      await pumpShopSurface(
        tester,
        home: Scaffold(
          body: Padding(
            padding: AppSpacing.page,
            child: ProductCardGridView(
              itemCount: 2,
              itemBuilder: (context, index) {
                final name = index == 0
                    ? longVietnameseProductName
                    : shortVietnameseProductName;
                return ProductCard(
                  title: name,
                  priceAmount: 4500000,
                  compareAtAmount: 5290000,
                  stockQuantity: 3,
                  isFavorite: favorite,
                  onTap: () => tapped = true,
                  onFavoritePressed: (next) => favorite = next,
                );
              },
            ),
          ),
        ),
      );

      expectNoFlutterOverflow(tester);

      final cards = find.byType(ProductCard);
      expect(cards, findsNWidgets(2));
      expect(tester.getSize(cards.at(0)), tester.getSize(cards.at(1)));

      final titleFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == longVietnameseProductName,
      );
      expect(titleFinder, findsOneWidget);
      final title = tester.widget<Text>(titleFinder);
      expect(title.maxLines, ProductCardLayout.titleMaxLines);
      expect(title.overflow, TextOverflow.ellipsis);
      expectCardSemanticsContains(tester, longVietnameseProductName);

      expectWidgetFits(tester, titleFinder, cards.at(0));

      final mediaFinders = find.descendant(
        of: cards,
        matching: find.byType(AspectRatio),
      );
      expect(mediaFinders, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final media = tester.widget<AspectRatio>(mediaFinders.at(i));
        final mediaSize = tester.getSize(mediaFinders.at(i));
        final cardSize = tester.getSize(cards.at(i));
        expect(media.aspectRatio, ProductCardLayout.mediaAspectRatio);
        expect(mediaSize.width, greaterThan(0));
        expect(mediaSize.width, closeTo(mediaSize.height, 0.5));
        expect(
          mediaSize.width,
          closeTo(cardSize.width - AppSpacing.card.horizontal, 0.5),
        );
      }

      expect(find.byType(PriceLabel), findsNWidgets(2));
      expect(find.byType(StockIndicator), findsNWidgets(2));
      expect(find.text('Only 3 left'), findsNWidgets(2));
      expect(find.text('Sale'), findsNWidgets(2));
      expect(find.textContaining('₫'), findsWidgets);

      await tester.tap(cards.at(0));
      await tester.pump();
      expect(tapped, isTrue);

      await tester.tap(find.byType(FavoriteButton).first);
      await tester.pump();
      expect(favorite, isTrue);
    },
  );

  testWidgets(
    'one-line and two-line titles keep price and stock visible without overflow',
    (tester) async {
      await pumpShopSurface(
        tester,
        home: const Scaffold(
          body: ProductCard(
            title: shortVietnameseProductName,
            priceAmount: 1890000,
            compareAtAmount: 2190000,
            stockQuantity: 8,
          ),
        ),
      );

      expectNoFlutterOverflow(tester);
      expect(find.text(shortVietnameseProductName), findsOneWidget);
      expect(find.text('In stock'), findsOneWidget);
      expect(find.textContaining('1.890.000'), findsOneWidget);
      expect(find.textContaining('2.190.000'), findsOneWidget);
    },
  );
}
