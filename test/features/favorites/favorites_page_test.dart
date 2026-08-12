import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/favorites/di/favorites_providers.dart';
import 'package:base_project/features/favorites/domain/entities/favorite.dart';
import 'package:base_project/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:base_project/features/favorites/presentation/views/favorites_page.dart';
import 'package:base_project/features/product/di/product_providers.dart';
import 'package:base_project/features/product/domain/repositories/product_repository.dart';
import 'package:base_project/shared/widgets/shop/favorite_button.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:base_project/shared/widgets/shop/product_card_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../shared/widgets/shop/product_card_test_support.dart';

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

class _MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late _MockFavoriteRepository favoriteRepository;
  late _MockProductRepository productRepository;

  setUp(() {
    favoriteRepository = _MockFavoriteRepository();
    productRepository = _MockProductRepository();
  });

  testWidgets(
    'favorites grid stays overflow-free for long Vietnamese names at 320dp',
    (tester) async {
      final longProduct = denseProduct();
      final shortProduct = denseProduct(
        id: 'prod-2',
        name: shortVietnameseProductName,
      );

      when(() => favoriteRepository.list()).thenAnswer(
        (_) async => const Success([
          Favorite(id: 'fav-1', userId: 'user-1', productId: 'prod-1'),
          Favorite(id: 'fav-2', userId: 'user-1', productId: 'prod-2'),
        ]),
      );
      when(
        () => productRepository.getById('prod-1'),
      ).thenAnswer((_) async => Success(longProduct));
      when(
        () => productRepository.getById('prod-2'),
      ).thenAnswer((_) async => Success(shortProduct));
      when(
        () => favoriteRepository.remove('prod-1'),
      ).thenAnswer((_) async => const Success<void>(null));

      final router = GoRouter(
        initialLocation: AppRoutes.favorites,
        routes: [
          GoRoute(
            path: AppRoutes.favorites,
            builder: (_, __) => const FavoritesPage(),
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
        overrides: [
          favoriteRepositoryProvider.overrideWithValue(favoriteRepository),
          productRepositoryProvider.overrideWithValue(productRepository),
        ],
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

      await tester.tap(find.byType(FavoriteButton).first);
      await tester.pumpAndSettle();
      verify(() => favoriteRepository.remove('prod-1')).called(1);

      await tester.tap(find.byType(ProductCard).at(1));
      await tester.pumpAndSettle();
      expect(find.text('product-prod-2'), findsOneWidget);
    },
  );
}
