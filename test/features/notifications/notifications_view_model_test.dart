import 'dart:async';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/notifications/di/notifications_providers.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:base_project/features/notifications/presentation/view_models/notifications_state.dart';
import 'package:base_project/features/notifications/presentation/view_models/notifications_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_container.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

AppNotification _notification({
  String id = 'n1',
  bool isRead = false,
  String title = 'Title',
  String body = 'Body',
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
    createdAt: createdAt ?? DateTime.utc(2026, 8, 10, 10),
  );
}

List<AppNotification> _page(int count, {int start = 1, bool isRead = false}) {
  return [
    for (var i = 0; i < count; i++)
      _notification(
        id: 'n${start + i}',
        isRead: isRead,
        title: 'T${start + i}',
      ),
  ];
}

void main() {
  late _MockNotificationRepository repository;

  setUp(() {
    repository = _MockNotificationRepository();
  });

  Future<({ProviderContainer container, NotificationsViewModel vm})>
  createHarness() async {
    final container = await createTestContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
    );
    final sub = container.listen(
      notificationsViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(container.dispose);
    addTearDown(sub.close);

    // Allow constructor load to settle when stubbed synchronously.
    await Future<void>.delayed(Duration.zero);
    return (
      container: container,
      vm: container.read(notificationsViewModelProvider.notifier),
    );
  }

  test('initial load requests page 1 size 20 and exposes data', () async {
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success(_page(3)));

    final harness = await createHarness();
    await harness.vm.load();

    final state = harness.container.read(notificationsViewModelProvider);
    expect(state, isA<NotificationsContent>());
    final content = state as NotificationsContent;
    expect(content.items, hasLength(3));
    expect(content.hasMore, isFalse);
    expect(content.currentPage, 1);
    verify(
      () => repository.list(page: 1, pageSize: 20),
    ).called(greaterThanOrEqualTo(1));
  });

  test('initial load empty exposes empty content', () async {
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Success([]));

    final harness = await createHarness();
    await harness.vm.load();

    final state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('initial load failure exposes sanitized message only', () async {
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Failure(
        DatabaseException('select * from notifications leaked'),
      ),
    );

    final harness = await createHarness();
    await harness.vm.load();

    final state = harness.container.read(notificationsViewModelProvider);
    expect(state, isA<NotificationsFailure>());
    final failure = state as NotificationsFailure;
    expect(failure.message, NotificationsUiMessages.loadFailed);
    expect(failure.message, isNot(contains('select')));
    expect(failure.message, isNot(contains('notifications')));
  });

  test('network and auth failures map to sanitized copy', () async {
    expect(
      NotificationsViewModel.mapLoadFailure(
        const NetworkException('socket hang'),
      ),
      NotificationsUiMessages.network,
    );
    expect(
      NotificationsViewModel.mapLoadFailure(
        const UnauthorizedException('jwt expired raw'),
      ),
      NotificationsUiMessages.unauthenticated,
    );
  });

  test('pagination appends, dedups, and ends below page size', () async {
    when(
      () => repository.list(page: 1, pageSize: 20),
    ).thenAnswer((_) async => Success(_page(20)));
    when(() => repository.list(page: 2, pageSize: 20)).thenAnswer(
      (_) async => Success([
        _notification(id: 'n20', title: 'dup'),
        ..._page(5, start: 21),
      ]),
    );

    final harness = await createHarness();
    await harness.vm.load();
    await harness.vm.loadMore();

    final state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items, hasLength(25));
    expect(state.items.map((e) => e.id).toSet(), hasLength(25));
    expect(state.items.last.id, 'n25');
    expect(state.currentPage, 2);
    expect(state.hasMore, isFalse);
    verify(() => repository.list(page: 2, pageSize: 20)).called(1);
  });

  test(
    'pagination requests each next page at most once while loading',
    () async {
      final completer = Completer<Result<List<AppNotification>>>();
      when(
        () => repository.list(page: 1, pageSize: 20),
      ).thenAnswer((_) async => Success(_page(20)));
      when(
        () => repository.list(page: 2, pageSize: 20),
      ).thenAnswer((_) => completer.future);

      final harness = await createHarness();
      await harness.vm.load();

      final first = harness.vm.loadMore();
      final second = harness.vm.loadMore();
      final loadingState =
          harness.container.read(notificationsViewModelProvider)
              as NotificationsContent;
      expect(loadingState.isLoadingMore, isTrue);

      completer.complete(Success(_page(5, start: 21)));
      await Future.wait([first, second]);

      verify(() => repository.list(page: 2, pageSize: 20)).called(1);
    },
  );

  test(
    'pagination failure keeps items and allows retry of same page',
    () async {
      when(
        () => repository.list(page: 1, pageSize: 20),
      ).thenAnswer((_) async => Success(_page(20)));
      var page2Calls = 0;
      when(() => repository.list(page: 2, pageSize: 20)).thenAnswer((_) async {
        page2Calls++;
        if (page2Calls == 1) {
          return const Failure(DatabaseException('sql page 2'));
        }
        return Success(_page(5, start: 21));
      });

      final harness = await createHarness();
      await harness.vm.load();
      await harness.vm.loadMore();

      var state =
          harness.container.read(notificationsViewModelProvider)
              as NotificationsContent;
      expect(state.items, hasLength(20));
      expect(state.paginationError, NotificationsUiMessages.loadMoreFailed);
      expect(state.paginationError, isNot(contains('sql')));
      expect(state.currentPage, 1);
      expect(state.hasMore, isTrue);

      await harness.vm.loadMore();
      state =
          harness.container.read(notificationsViewModelProvider)
              as NotificationsContent;
      expect(state.items, hasLength(25));
      expect(state.paginationError, isNull);
      expect(state.currentPage, 2);
      expect(page2Calls, 2);
    },
  );

  test('refresh replaces items and resets pagination metadata', () async {
    when(
      () => repository.list(page: 1, pageSize: 20),
    ).thenAnswer((_) async => Success(_page(20)));
    when(
      () => repository.list(page: 2, pageSize: 20),
    ).thenAnswer((_) async => Success(_page(5, start: 21)));

    final harness = await createHarness();
    await harness.vm.load();
    await harness.vm.loadMore();

    when(
      () => repository.list(page: 1, pageSize: 20),
    ).thenAnswer((_) async => Success(_page(2, start: 100)));

    await harness.vm.refresh();

    final state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items.map((e) => e.id), ['n100', 'n101']);
    expect(state.currentPage, 1);
    expect(state.hasMore, isFalse);
    expect(state.isRefreshing, isFalse);
  });

  test('refresh failure preserves content with sanitized feedback', () async {
    when(
      () => repository.list(page: 1, pageSize: 20),
    ).thenAnswer((_) async => Success(_page(2)));

    final harness = await createHarness();
    await harness.vm.load();

    when(() => repository.list(page: 1, pageSize: 20)).thenAnswer(
      (_) async => const Failure(DatabaseException('refresh sql leak')),
    );

    await harness.vm.refresh();

    final state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items, hasLength(2));
    expect(state.actionFeedback, NotificationsUiMessages.refreshFailed);
    expect(state.actionFeedback, isNot(contains('sql')));
  });

  test('markRead success updates locally; failure leaves unchanged', () async {
    when(() => repository.list(page: 1, pageSize: 20)).thenAnswer(
      (_) async => Success([
        _notification(id: 'a', isRead: false),
        _notification(id: 'b', isRead: false),
      ]),
    );
    when(
      () => repository.markRead('a'),
    ).thenAnswer((_) async => const Success(null));

    final harness = await createHarness();
    await harness.vm.load();
    await harness.vm.markRead('a');

    var state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items.firstWhere((n) => n.id == 'a').isRead, isTrue);
    expect(state.items.firstWhere((n) => n.id == 'b').isRead, isFalse);

    when(
      () => repository.markRead('b'),
    ).thenAnswer((_) async => const Failure(DatabaseException('mark sql')));
    await harness.vm.markRead('b');
    state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items.firstWhere((n) => n.id == 'b').isRead, isFalse);
    expect(state.actionFeedback, NotificationsUiMessages.markReadFailed);
    expect(state.actionFeedback, isNot(contains('sql')));
  });

  test('markRead ignores duplicate in-flight and already-read items', () async {
    when(() => repository.list(page: 1, pageSize: 20)).thenAnswer(
      (_) async => Success([
        _notification(id: 'a', isRead: false),
        _notification(id: 'r', isRead: true),
      ]),
    );
    final completer = Completer<Result<void>>();
    when(() => repository.markRead('a')).thenAnswer((_) => completer.future);

    final harness = await createHarness();
    await harness.vm.load();

    final first = harness.vm.markRead('a');
    final second = harness.vm.markRead('a');
    await harness.vm.markRead('r');
    completer.complete(const Success(null));
    await Future.wait([first, second]);

    verify(() => repository.markRead('a')).called(1);
    verifyNever(() => repository.markRead('r'));
  });

  test('markAllRead success/failure and duplicate guard', () async {
    when(() => repository.list(page: 1, pageSize: 20)).thenAnswer(
      (_) async => Success([
        _notification(id: 'a', isRead: false),
        _notification(id: 'b', isRead: false),
      ]),
    );

    final completer = Completer<Result<void>>();
    when(() => repository.markAllRead()).thenAnswer((_) => completer.future);

    final harness = await createHarness();
    await harness.vm.load();

    final first = harness.vm.markAllRead();
    final second = harness.vm.markAllRead();
    completer.complete(const Success(null));
    await Future.wait([first, second]);
    verify(() => repository.markAllRead()).called(1);

    var state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items.every((n) => n.isRead), isTrue);

    when(() => repository.list(page: 1, pageSize: 20)).thenAnswer(
      (_) async => Success([
        _notification(id: 'a', isRead: false),
        _notification(id: 'b', isRead: false),
      ]),
    );
    await harness.vm.load();
    when(
      () => repository.markAllRead(),
    ).thenAnswer((_) async => const Failure(DatabaseException('all sql')));
    await harness.vm.markAllRead();
    state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.items.every((n) => !n.isRead), isTrue);
    expect(state.actionFeedback, NotificationsUiMessages.markAllReadFailed);
  });

  test('clearActionFeedback consumes snackbar message', () async {
    when(
      () => repository.list(page: 1, pageSize: 20),
    ).thenAnswer((_) async => Success(_page(1)));
    when(
      () => repository.markRead('n1'),
    ).thenAnswer((_) async => const Failure(NetworkException('down')));

    final harness = await createHarness();
    await harness.vm.load();
    await harness.vm.markRead('n1');

    var state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.actionFeedback, isNotNull);
    harness.vm.clearActionFeedback();
    state =
        harness.container.read(notificationsViewModelProvider)
            as NotificationsContent;
    expect(state.actionFeedback, isNull);
  });

  test('appendUnique preserves order and suppresses duplicate ids', () {
    final existing = _page(2, start: 1);
    final page = [
      _notification(id: 'n2', title: 'dup'),
      _notification(id: 'n3', title: 'new'),
    ];
    final merged = NotificationsViewModel.appendUniqueForTest(existing, page);
    expect(merged.map((e) => e.id), ['n1', 'n2', 'n3']);
    expect(merged[1].title, 'T2');
  });

  test('disposed view model does not commit late load results', () async {
    final completer = Completer<Result<List<AppNotification>>>();
    when(
      () => repository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => completer.future);

    final container = await createTestContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
    );
    final sub = container.listen(
      notificationsViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    final vm = container.read(notificationsViewModelProvider.notifier);
    expect(
      container.read(notificationsViewModelProvider),
      isA<NotificationsLoading>(),
    );

    sub.close();
    container.dispose();
    completer.complete(Success(_page(1)));
    await pumpEventQueue();

    // Disposed notifier must not throw when the future completes.
    expect(vm.mounted, isFalse);
  });
}
