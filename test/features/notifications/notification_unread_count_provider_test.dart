import 'dart:collection';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/notifications/di/notifications_providers.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_container.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late _MockNotificationRepository repository;

  setUp(() {
    repository = _MockNotificationRepository();
  });

  Future<ProviderContainer> createContainer() async {
    final container = await createTestContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads unread count once per active lifecycle', () async {
    when(
      () => repository.unreadCount(),
    ).thenAnswer((_) async => const Success(7));

    final container = await createContainer();
    final sub = container.listen<AsyncValue<int?>>(
      notificationUnreadCountProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(await container.read(notificationUnreadCountProvider.future), 7);
    expect(container.read(notificationUnreadCountProvider).value, 7);
    verify(() => repository.unreadCount()).called(1);
  });

  test(
    'zero and negative successes are exposed as non-negative counts',
    () async {
      when(
        () => repository.unreadCount(),
      ).thenAnswer((_) async => const Success(0));

      final zeroContainer = await createContainer();
      final zeroSub = zeroContainer.listen<AsyncValue<int?>>(
        notificationUnreadCountProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(zeroSub.close);

      expect(
        await zeroContainer.read(notificationUnreadCountProvider.future),
        0,
      );

      when(
        () => repository.unreadCount(),
      ).thenAnswer((_) async => const Success(-4));

      final negativeContainer = await createContainer();
      final negativeSub = negativeContainer.listen<AsyncValue<int?>>(
        notificationUnreadCountProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(negativeSub.close);

      expect(
        await negativeContainer.read(notificationUnreadCountProvider.future),
        0,
      );
    },
  );

  test('failure is sanitized to an omitted badge state', () async {
    when(() => repository.unreadCount()).thenAnswer(
      (_) async =>
          const Failure(DatabaseException('select unread_count() raw sql')),
    );

    final container = await createContainer();
    final sub = container.listen<AsyncValue<int?>>(
      notificationUnreadCountProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(
      await container.read(notificationUnreadCountProvider.future),
      isNull,
    );
    expect(container.read(notificationUnreadCountProvider).value, isNull);
  });

  test('refresh and invalidation request a new unread count', () async {
    final unreadResults = Queue<Result<int>>.of([
      const Success(2),
      const Success(5),
      const Success(1),
    ]);
    when(
      () => repository.unreadCount(),
    ).thenAnswer((_) async => unreadResults.removeFirst());

    final container = await createContainer();
    final sub = container.listen<AsyncValue<int?>>(
      notificationUnreadCountProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(await container.read(notificationUnreadCountProvider.future), 2);

    await container.read(notificationUnreadCountProvider.notifier).refresh();
    expect(container.read(notificationUnreadCountProvider).value, 5);

    container.invalidate(notificationUnreadCountProvider);
    expect(await container.read(notificationUnreadCountProvider.future), 1);
    verify(() => repository.unreadCount()).called(3);
  });
}
