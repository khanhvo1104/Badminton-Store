import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const longVietnameseProductName =
    'Vợt cầu lông Yonex Astrox 99 Pro 3U G5 Limited Edition '
    'Championship Series dành cho người chơi tấn công chuyên nghiệp';

const shortVietnameseProductName = 'Vợt Yonex Astrox 99';

Product denseProduct({
  String id = 'prod-1',
  String name = longVietnameseProductName,
  double price = 4500000,
  double compareAtPrice = 5290000,
  int stockQuantity = 3,
}) {
  return Product(
    id: id,
    name: name,
    slug: '$id-slug',
    categoryId: 'cat-1',
    status: 'active',
    variants: [
      ProductVariant(
        id: '$id-var',
        productId: id,
        sku: 'SKU-$id',
        price: price,
        compareAtPrice: compareAtPrice,
        isDefault: true,
        availableQuantity: stockQuantity,
      ),
    ],
  );
}

Future<void> pumpShopSurface(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const [],
  Size size = const Size(320, 1200),
  double textScale = 1.3,
  RouterConfig<Object>? routerConfig,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final app = ProviderScope(
    overrides: overrides,
    child: routerConfig == null
        ? MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              );
            },
            home: home,
          )
        : MaterialApp.router(
            theme: AppTheme.light(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              );
            },
            routerConfig: routerConfig,
          ),
  );

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void expectNoFlutterOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}

void expectCardSemanticsContains(WidgetTester tester, String fullName) {
  final semantics = tester.ensureSemantics();
  try {
    expect(
      tester.getSemantics(find.byType(ProductCard).first).label,
      contains(fullName),
    );
  } finally {
    semantics.dispose();
  }
}

void expectWidgetFits(WidgetTester tester, Finder child, Finder parent) {
  final childRect = tester.getRect(child);
  final parentRect = tester.getRect(parent);
  const epsilon = 0.5;
  expect(childRect.left, greaterThanOrEqualTo(parentRect.left - epsilon));
  expect(childRect.top, greaterThanOrEqualTo(parentRect.top - epsilon));
  expect(childRect.right, lessThanOrEqualTo(parentRect.right + epsilon));
  expect(childRect.bottom, lessThanOrEqualTo(parentRect.bottom + epsilon));
}
