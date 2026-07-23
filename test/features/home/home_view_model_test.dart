import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:base_project/features/home/domain/repositories/home_repository.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:base_project/features/home/presentation/view_models/home_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/test_container.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  test('home loads dashboard items', () async {
    final repository = _MockHomeRepository();
    when(() => repository.getDashboardItems()).thenAnswer(
      (_) async => const Success([
        DashboardItem(
          id: '1',
          title: 'Title',
          subtitle: 'Subtitle',
          iconName: 'devices',
        ),
      ]),
    );

    final container = await createTestContainer(
      overrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      homeViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(homeViewModelProvider.notifier).load();

    expect(container.read(homeViewModelProvider), isA<HomeLoaded>());
  });

  test('home refresh reloads data', () async {
    final repository = _MockHomeRepository();
    var calls = 0;
    when(() => repository.getDashboardItems()).thenAnswer((_) async {
      calls++;
      return const Success([
        DashboardItem(
          id: '1',
          title: 'Title',
          subtitle: 'Subtitle',
          iconName: 'devices',
        ),
      ]);
    });

    final container = await createTestContainer(
      overrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      homeViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(homeViewModelProvider.notifier).load();
    final afterLoad = calls;
    await container.read(homeViewModelProvider.notifier).refresh();

    expect(calls, afterLoad + 1);
  });

  test('home error state is set on failure', () async {
    final repository = _MockHomeRepository();
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Failure(NetworkException('offline')));

    final container = await createTestContainer(
      overrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      homeViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(homeViewModelProvider.notifier).load();

    final state = container.read(homeViewModelProvider);
    expect(state, isA<HomeError>());
    expect((state as HomeError).message, 'offline');
  });
}
