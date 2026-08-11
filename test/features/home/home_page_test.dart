import 'dart:async';

import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:base_project/features/home/domain/repositories/home_repository.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:base_project/features/home/presentation/views/home_page.dart';
import 'package:base_project/features/home/presentation/widgets/featured_product_card.dart';
import 'package:base_project/shared/providers/current_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

const _user = User(
  id: 'user-1',
  email: 'demo@example.com',
  displayName: 'Alex Player',
);

const _itemA = DashboardItem(
  id: 'prod-1',
  title: 'Yonex Astrox 99',
  subtitle: 'Offensive racket',
  iconName: 'sports',
);

const _itemB = DashboardItem(
  id: 'prod-2',
  title: 'Victor shoes',
  subtitle: 'Stable footwear',
  iconName: 'footwear',
);

void main() {
  late _MockHomeRepository repository;
  late GoRouter router;

  setUp(() {
    repository = _MockHomeRepository();
  });

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomePage()),
        GoRoute(
          path: AppRoutes.catalog,
          builder: (_, __) => const Scaffold(body: Text('catalog-page')),
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
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeRepositoryProvider.overrideWithValue(repository),
          currentUserProvider.overrideWithValue(_user),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('loaded home greets user with store copy and featured order', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA, _itemB]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_greeting')), findsOneWidget);
    expect(find.text('Hello, Alex Player'), findsOneWidget);
    expect(find.text(HomeUiMessages.subtitle), findsOneWidget);
    expect(find.textContaining('overview'), findsNothing);
    expect(find.textContaining('dashboard'), findsNothing);
    expect(find.byKey(const Key('home_featured_section')), findsOneWidget);
    expect(find.byKey(const Key('home_featured_item_prod-1')), findsOneWidget);
    expect(find.byKey(const Key('home_featured_item_prod-2')), findsOneWidget);

    final cards = tester
        .widgetList<FeaturedProductCard>(find.byType(FeaturedProductCard))
        .toList();
    expect(cards.map((card) => card.item.id), ['prod-1', 'prod-2']);
  });

  testWidgets('empty state offers catalog and keeps pull-to-refresh', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_empty')), findsOneWidget);
    expect(find.text(HomeUiMessages.emptyTitle), findsOneWidget);
    expect(find.byKey(const Key('home_empty_catalog')), findsOneWidget);

    final emptyList = tester.widget<ListView>(
      find.byKey(const Key('home_empty')),
    );
    expect(emptyList.physics, isA<AlwaysScrollableScrollPhysics>());

    await tester.tap(find.byKey(const Key('home_empty_catalog')));
    await tester.pumpAndSettle();
    expect(find.text('catalog-page'), findsOneWidget);
  });

  testWidgets('failure shows sanitized copy and retry recovers', (
    tester,
  ) async {
    when(() => repository.getDashboardItems()).thenAnswer(
      (_) async => const Failure(DatabaseException('SELECT explode')),
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_error')), findsOneWidget);
    expect(find.text(HomeUiMessages.loadFailed), findsOneWidget);
    expect(find.textContaining('SELECT'), findsNothing);
    expect(find.byKey(const Key('home_retry')), findsOneWidget);

    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));
    await tester.tap(find.byKey(const Key('home_retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_loaded')), findsOneWidget);
    expect(find.byKey(const Key('home_featured_item_prod-1')), findsOneWidget);
  });

  testWidgets('catalog and search actions navigate without shell changes', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_catalog_action')));
    await tester.pumpAndSettle();
    expect(find.text('catalog-page'), findsOneWidget);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_search_action')));
    await tester.pumpAndSettle();
    expect(find.text('search-page'), findsOneWidget);
  });

  testWidgets('featured item navigates to product detail', (tester) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_featured_item_prod-1')));
    await tester.pumpAndSettle();
    expect(find.text('product-prod-1'), findsOneWidget);
  });

  testWidgets('featured item activates from keyboard focus', (tester) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key('home_featured_item_prod-1'));
    expect(
      find.descendant(
        of: cardFinder,
        matching: find.byType(FocusableActionDetector),
      ),
      findsOneWidget,
    );

    FocusNode cardFocus() {
      return Focus.of(
        tester.element(
          find.descendant(
            of: cardFinder,
            matching: find.byType(GestureDetector),
          ),
        ),
      );
    }

    final enterFocus = cardFocus()..requestFocus();
    await tester.pump();
    expect(enterFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('product-prod-1'), findsOneWidget);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    final spaceFocus = cardFocus()..requestFocus();
    await tester.pump();
    expect(spaceFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('product-prod-1'), findsOneWidget);
  });

  testWidgets('featured cards expose concise product semantics labels', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(
      find.byKey(const Key('home_featured_item_prod-1')),
    );
    expect(semantics.label, 'Yonex Astrox 99');
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('narrow layout stacks featured items in one column', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA, _itemB]));

    await pumpHome(tester, size: const Size(390, 900));
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(
      find.byKey(const Key('home_featured_item_prod-1')),
    );
    final second = tester.getTopLeft(
      find.byKey(const Key('home_featured_item_prod-2')),
    );
    expect(second.dy, greaterThan(first.dy));
  });

  testWidgets('wide layout uses two-column wrap for featured items', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA, _itemB]));

    await pumpHome(tester, size: const Size(900, 1200));
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(
      find.byKey(const Key('home_featured_item_prod-1')),
    );
    final second = tester.getTopLeft(
      find.byKey(const Key('home_featured_item_prod-2')),
    );
    expect(first.dy, second.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('pull-to-refresh invokes refresh once on loaded state', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    await pumpHome(tester);
    await tester.pumpAndSettle();
    clearInteractions(repository);

    final completer = Completer<Result<List<DashboardItem>>>();
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) => completer.future);

    await tester.fling(
      find.byKey(const Key('home_loaded')),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    completer.complete(const Success([_itemB]));
    await tester.pumpAndSettle();

    verify(() => repository.getDashboardItems()).called(1);
    expect(find.byKey(const Key('home_featured_item_prod-2')), findsOneWidget);
  });

  testWidgets('refresh failure keeps items and shows snackbar once', (
    tester,
  ) async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    await pumpHome(tester);
    await tester.pumpAndSettle();

    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Failure(NetworkException('offline raw')));

    await tester.fling(
      find.byKey(const Key('home_loaded')),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_featured_item_prod-1')), findsOneWidget);
    expect(find.text(HomeUiMessages.network), findsOneWidget);
    expect(find.textContaining('offline raw'), findsNothing);

    // Rebuild should not replay consumed feedback.
    await tester.pump();
    expect(find.text(HomeUiMessages.network), findsOneWidget);
  });

  testWidgets('loading state uses stable key', (tester) async {
    final completer = Completer<Result<List<DashboardItem>>>();
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) => completer.future);

    await pumpHome(tester);
    await tester.pump();

    expect(find.byKey(const Key('home_loading')), findsOneWidget);
    expect(find.text(HomeUiMessages.loading), findsOneWidget);

    completer.complete(const Success([]));
    await tester.pumpAndSettle();
  });
}
