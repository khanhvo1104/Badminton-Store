import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/search/di/search_providers.dart';
import 'package:base_project/features/search/domain/repositories/search_repository.dart';
import 'package:base_project/features/search/presentation/views/search_page.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:base_project/shared/widgets/shop/product_card_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../shared/widgets/shop/product_card_test_support.dart';

class _MockSearchRepository extends Mock implements SearchRepository {}

void main() {
  late _MockSearchRepository searchRepository;

  setUp(() {
    searchRepository = _MockSearchRepository();
  });

  testWidgets(
    'search grid stays overflow-free for long Vietnamese names at 320dp',
    (tester) async {
      when(
        () => searchRepository.recentQueries(),
      ).thenAnswer((_) async => const Success(<String>[]));
      when(
        () => searchRepository.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Success([
          denseProduct(),
          denseProduct(id: 'prod-2', name: shortVietnameseProductName),
        ]),
      );

      final router = GoRouter(
        initialLocation: AppRoutes.search,
        routes: [
          GoRoute(
            path: AppRoutes.search,
            builder: (_, __) => const SearchPage(),
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
          searchRepositoryProvider.overrideWithValue(searchRepository),
        ],
        routerConfig: router,
        home: const SizedBox.shrink(),
      );

      await tester.enterText(find.byType(TextField), 'yonex');
      await tester.pumpAndSettle();

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
