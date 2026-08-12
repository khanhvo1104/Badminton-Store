import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/catalog/di/catalog_providers.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';
import 'package:base_project/features/catalog/domain/repositories/category_repository.dart';
import 'package:base_project/features/catalog/presentation/views/catalog_page.dart';
import 'package:base_project/features/product/di/product_providers.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/product/domain/repositories/product_repository.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:base_project/shared/widgets/shop/product_card_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../shared/widgets/shop/product_card_test_support.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late _MockProductRepository productRepository;
  late _MockCategoryRepository categoryRepository;

  setUp(() {
    productRepository = _MockProductRepository();
    categoryRepository = _MockCategoryRepository();
  });

  List<Override> overrides() => [
    productRepositoryProvider.overrideWithValue(productRepository),
    categoryRepositoryProvider.overrideWithValue(categoryRepository),
  ];

  void stubCatalog({
    required List<Product> products,
    List<Category> categories = const [],
  }) {
    when(
      () => categoryRepository.list(),
    ).thenAnswer((_) async => Success(categories));
    when(
      () => productRepository.list(
        categoryId: any(named: 'categoryId'),
        brandId: any(named: 'brandId'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success(products));
  }

  testWidgets(
    'catalog grid stays overflow-free for long Vietnamese names at 320dp',
    (tester) async {
      stubCatalog(
        products: [
          denseProduct(),
          denseProduct(id: 'prod-2', name: shortVietnameseProductName),
        ],
      );

      final router = GoRouter(
        initialLocation: AppRoutes.catalog,
        routes: [
          GoRoute(
            path: AppRoutes.catalog,
            builder: (_, __) => const CatalogPage(),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, __) => const Scaffold(body: Text('search-page')),
          ),
          GoRoute(
            path: AppRoutes.product,
            builder: (_, state) =>
                Scaffold(body: Text('product-${state.pathParameters['id']}')),
          ),
        ],
      );

      await pumpShopSurface(
        tester,
        overrides: overrides(),
        routerConfig: router,
        home: const SizedBox.shrink(),
      );

      expect(find.byType(ProductCardGridView), findsOneWidget);
      expect(find.byType(ProductCard), findsNWidgets(2));
      expectNoFlutterOverflow(tester);
      expectCardSemanticsContains(tester, longVietnameseProductName);
      expect(find.text('Only 3 left'), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(ProductCard).at(0)),
        tester.getSize(find.byType(ProductCard).at(1)),
      );

      await tester.tap(find.byType(ProductCard).first);
      await tester.pumpAndSettle();
      expect(find.text('product-prod-1'), findsOneWidget);
    },
  );
}
