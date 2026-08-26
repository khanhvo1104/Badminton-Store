import 'dart:async';

import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/notifications/di/notifications_providers.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:base_project/features/notifications/presentation/view_models/notifications_state.dart';
import 'package:base_project/features/notifications/presentation/views/notifications_page.dart';
import 'package:base_project/features/notifications/presentation/widgets/notification_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

AppNotification _notification({
  String id = 'n1',
  bool isRead = false,
  String title = 'Order update title',
  String body = 'Your order shipped',
  NotificationType type = NotificationType.orderUpdate,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: id,
    userId: 'user-1',
    title: title,
    body: body,
    type: type,
    isRead: isRead,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 10, 3, 30),
  );
}

void main() {
  late _MockNotificationRepository repository;

  setUp(() {
    repository = _MockNotificationRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationsPage(),
        ),
      ),
    );
  }

  late GoRouter router;

  GoRouter buildRouter({String initialLocation = AppRoutes.notifications}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('home-shell-page')),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, __) => const NotificationsPage(),
        ),
        GoRoute(
          path: AppRoutes.orders,
          builder: (_, __) => const Scaffold(body: Text('orders-page')),
        ),
      ],
    );
  }

  Future<void> pumpRoutedPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('loading then empty state with pull-to-refresh physics', (
    tester,
  ) async {
    final completer = Completer<Result<List<AppNotification>>>();
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => completer.future);

    await pumpPage(tester);
    await tester.pump();
    expect(find.byKey(const Key('notifications_loading')), findsOneWidget);

    completer.complete(const Success([]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications_empty')), findsOneWidget);
    expect(find.text(NotificationsUiMessages.empty), findsOneWidget);
    expect(find.byKey(const Key('notifications_mark_all_read')), findsNothing);

    final emptyList = tester.widget<ListView>(
      find.byKey(const Key('notifications_empty')),
    );
    expect(emptyList.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('full-screen error shows sanitized copy and retry', (
    tester,
  ) async {
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Failure(DatabaseException('sql explode')));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications_error')), findsOneWidget);
    expect(find.text(NotificationsUiMessages.loadFailed), findsOneWidget);
    expect(find.textContaining('sql'), findsNothing);

    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Success([]));

    await tester.tap(find.byKey(const Key('notifications_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications_empty')), findsOneWidget);
  });

  testWidgets('populated list renders unread/read, type, timestamp, mark all', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026, 8, 10, 3, 30);
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success([
        _notification(
          id: 'unread-1',
          isRead: false,
          type: NotificationType.promotion,
          createdAt: createdAt,
        ),
        _notification(
          id: 'unread-2',
          isRead: false,
          title: 'Second unread',
          body: 'Still unread',
          type: NotificationType.system,
          createdAt: createdAt,
        ),
        _notification(
          id: 'read-1',
          isRead: true,
          title: 'Read title',
          body: 'Already read',
          type: NotificationType.promotion,
          createdAt: createdAt,
        ),
      ]),
    );
    when(
      () => repository.markRead('unread-1'),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repository.markAllRead(),
    ).thenAnswer((_) async => const Success(null));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byKey(const Key('notifications_list')), findsOneWidget);
    expect(
      find.byKey(const Key('notifications_item_unread-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notifications_item_unread_unread-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notifications_item_read-1')), findsOneWidget);
    expect(
      find.byKey(const Key('notifications_item_timestamp_unread-1')),
      findsOneWidget,
    );
    final listContext = tester.element(
      find.byKey(const Key('notifications_list')),
    );
    final expectedTimestamp = formatNotificationTimestamp(
      createdAt,
      localizations: MaterialLocalizations.of(listContext),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(listContext),
    );
    expect(find.text(expectedTimestamp), findsWidgets);
    expect(
      find.byKey(const Key('notifications_mark_all_read')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('notifications_item_read-1')));
    await tester.pumpAndSettle();
    verifyNever(() => repository.markRead('read-1'));

    await tester.tap(find.byKey(const Key('notifications_item_unread-1')));
    await tester.pumpAndSettle();
    verify(() => repository.markRead('unread-1')).called(1);
    expect(
      find.byKey(const Key('notifications_item_unread_unread-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('notifications_mark_all_read')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('notifications_mark_all_read')));
    await tester.pumpAndSettle();
    verify(() => repository.markAllRead()).called(1);
    expect(find.byKey(const Key('notifications_mark_all_read')), findsNothing);
  });

  testWidgets('pagination footer shows loading and retry feedback', (
    tester,
  ) async {
    when(() => repository.list(page: 1, pageSize: 20)).thenAnswer(
      (_) async => Success([
        for (var i = 1; i <= 20; i++)
          _notification(id: 'n$i', title: 'Title $i'),
      ]),
    );
    final page2 = Completer<Result<List<AppNotification>>>();
    when(
      () => repository.list(page: 2, pageSize: 20),
    ).thenAnswer((_) => page2.future);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('notifications_list')),
      const Offset(0, -4000),
    );
    await tester.pump();
    expect(find.byKey(const Key('notifications_loading_more')), findsOneWidget);

    page2.complete(const Failure(DatabaseException('page2 sql')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notifications_pagination_error')),
      findsOneWidget,
    );
    expect(find.text(NotificationsUiMessages.loadMoreFailed), findsOneWidget);
    expect(find.textContaining('sql'), findsNothing);

    when(() => repository.list(page: 2, pageSize: 20)).thenAnswer(
      (_) async => Success([_notification(id: 'n21', title: 'Title 21')]),
    );
    await tester.tap(find.byKey(const Key('notifications_pagination_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Title 21'), findsOneWidget);
    expect(
      find.byKey(const Key('notifications_pagination_error')),
      findsNothing,
    );
  });

  test('formatNotificationTimestamp adapts to MaterialLocalizations', () {
    final createdAt = DateTime(2026, 8, 10, 15, 30);
    final english = formatNotificationTimestamp(
      createdAt,
      localizations: const DefaultMaterialLocalizations(),
      alwaysUse24HourFormat: true,
    );
    final custom = formatNotificationTimestamp(
      createdAt,
      localizations: const _YmdMaterialLocalizations(),
      alwaysUse24HourFormat: true,
    );

    expect(english, 'Aug 10, 2026 15:30');
    expect(custom, '2026-08-10 15:30');
    expect(english, isNot(equals(custom)));
  });

  testWidgets('list timestamp follows active MaterialLocalizations', (
    tester,
  ) async {
    final createdAt = DateTime(2026, 8, 10, 15, 30);
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success([_notification(id: 'n1', createdAt: createdAt)]),
    );

    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            _YmdMaterialLocalizationsDelegate(),
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          home: const NotificationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-08-10 3:30 PM'), findsOneWidget);
    expect(find.text('Aug 10, 2026 3:30 PM'), findsNothing);
  });

  testWidgets('refresh failure keeps list and shows snackbar feedback', (
    tester,
  ) async {
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success([_notification()]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Failure(DatabaseException('refresh boom')));

    await tester.fling(
      find.byKey(const Key('notifications_list')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications_list')), findsOneWidget);
    expect(find.text(NotificationsUiMessages.refreshFailed), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  group('order_update navigation', () {
    testWidgets('unread order_update marks once and pushes AppRoutes.orders', (
      tester,
    ) async {
      when(
        () => repository.list(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async =>
            Success([_notification(id: 'order-unread', isRead: false)]),
      );
      when(
        () => repository.markRead('order-unread'),
      ).thenAnswer((_) async => const Success(null));

      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.notifications);

      await tester.tap(
        find.byKey(const Key('notifications_item_order-unread')),
      );
      await tester.pumpAndSettle();

      verify(() => repository.markRead('order-unread')).called(1);
      expect(router.state.uri.toString(), AppRoutes.orders);
      expect(find.text('orders-page'), findsOneWidget);
    });

    testWidgets('read order_update pushes AppRoutes.orders without markRead', (
      tester,
    ) async {
      when(
        () => repository.list(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Success([_notification(id: 'order-read', isRead: true)]),
      );

      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notifications_item_order-read')));
      await tester.pumpAndSettle();

      verifyNever(() => repository.markRead(any()));
      expect(router.state.uri.toString(), AppRoutes.orders);
      expect(find.text('orders-page'), findsOneWidget);
    });

    testWidgets('markRead failure still pushes and snackbar stays sanitized', (
      tester,
    ) async {
      final markReadCompleter = Completer<Result<void>>();
      when(
        () => repository.list(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Success([_notification(id: 'order-fail', isRead: false)]),
      );
      when(
        () => repository.markRead('order-fail'),
      ).thenAnswer((_) => markReadCompleter.future);

      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notifications_item_order-fail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(router.state.uri.toString(), AppRoutes.orders);
      expect(find.text('orders-page'), findsOneWidget);
      verify(() => repository.markRead('order-fail')).called(1);

      markReadCompleter.complete(
        const Failure(DatabaseException('markRead sql boom')),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.orders);
      expect(find.text(NotificationsUiMessages.markReadFailed), findsOneWidget);
      expect(find.textContaining('sql'), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('non-order types do not push to orders', (tester) async {
      when(
        () => repository.list(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Success([
          _notification(
            id: 'promo',
            isRead: false,
            type: NotificationType.promotion,
            title: 'Promo',
          ),
          _notification(
            id: 'sys',
            isRead: true,
            type: NotificationType.system,
            title: 'System',
          ),
          _notification(
            id: 'stock',
            isRead: false,
            type: NotificationType.stockAlert,
            title: 'Stock',
          ),
        ]),
      );
      when(
        () => repository.markRead(any()),
      ).thenAnswer((_) async => const Success(null));

      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notifications_item_promo')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.notifications);
      verify(() => repository.markRead('promo')).called(1);

      await tester.tap(find.byKey(const Key('notifications_item_sys')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.notifications);
      verifyNever(() => repository.markRead('sys'));

      await tester.tap(find.byKey(const Key('notifications_item_stock')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.notifications);
      verify(() => repository.markRead('stock')).called(1);

      expect(find.text('orders-page'), findsNothing);
    });

    testWidgets('back from orders restores notifications route', (
      tester,
    ) async {
      when(
        () => repository.list(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Success([_notification(id: 'order-back', isRead: true)]),
      );

      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notifications_item_order-back')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.orders);

      router.pop();
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.notifications);
      expect(find.text('Notifications'), findsOneWidget);
      expect(
        find.byKey(const Key('notifications_item_order-back')),
        findsOneWidget,
      );
    });
  });
}

/// Material localizations with year-month-day compact dates for locale tests.
class _YmdMaterialLocalizations extends DefaultMaterialLocalizations {
  const _YmdMaterialLocalizations();

  @override
  String formatShortDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _YmdMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _YmdMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const _YmdMaterialLocalizations();
  }

  @override
  bool shouldReload(_YmdMaterialLocalizationsDelegate old) => false;
}
