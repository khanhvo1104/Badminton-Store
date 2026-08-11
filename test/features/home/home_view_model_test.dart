import 'dart:async';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:base_project/features/home/domain/repositories/home_repository.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:base_project/features/home/presentation/view_models/home_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_container.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

const _itemA = DashboardItem(
  id: 'a',
  title: 'Yonex Astrox',
  subtitle: 'Attack racket',
  iconName: 'sports',
);

const _itemB = DashboardItem(
  id: 'b',
  title: 'Li-Ning shoes',
  subtitle: 'Court footwear',
  iconName: 'footwear',
);

void main() {
  late _MockHomeRepository repository;

  setUp(() {
    repository = _MockHomeRepository();
  });

  Future<({ProviderContainer container, HomeViewModel vm})>
  createHarness() async {
    final container = await createTestContainer(
      overrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    final subscription = container.listen(
      homeViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(container.dispose);
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    return (
      container: container,
      vm: container.read(homeViewModelProvider.notifier),
    );
  }

  test('load success preserves repository order', () async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA, _itemB]));

    final harness = await createHarness();
    await harness.vm.load();

    final state = harness.container.read(homeViewModelProvider);
    expect(state, isA<HomeLoaded>());
    expect((state as HomeLoaded).items, [_itemA, _itemB]);
  });

  test('load empty yields HomeEmpty', () async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([]));

    final harness = await createHarness();
    await harness.vm.load();
    expect(harness.container.read(homeViewModelProvider), isA<HomeEmpty>());
  });

  test('initial failure uses sanitized copy, never raw backend text', () async {
    when(() => repository.getDashboardItems()).thenAnswer(
      (_) async => const Failure(DatabaseException('SELECT * FROM boom')),
    );

    final harness = await createHarness();
    await harness.vm.load();

    final state = harness.container.read(homeViewModelProvider);
    expect(state, isA<HomeError>());
    expect((state as HomeError).message, HomeUiMessages.loadFailed);
    expect(state.message, isNot(contains('SELECT')));
  });

  test('network and auth failures map to sanitized messages', () {
    expect(
      HomeViewModel.mapLoadFailure(const NetworkException('socket hang')),
      HomeUiMessages.network,
    );
    expect(
      HomeViewModel.mapLoadFailure(
        const AuthenticationException('jwt expired raw'),
      ),
      HomeUiMessages.unauthenticated,
    );
    expect(
      HomeViewModel.mapLoadFailure(
        const UnauthorizedException('RLS denied sql'),
      ),
      HomeUiMessages.unauthenticated,
    );
    expect(
      HomeViewModel.mapRefreshFailure(const ServerException('500 stack')),
      HomeUiMessages.refreshFailed,
    );
  });

  test('retry recovers from initial failure', () async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Failure(NetworkException('offline')));

    final harness = await createHarness();
    await harness.vm.load();
    expect(harness.container.read(homeViewModelProvider), isA<HomeError>());

    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));
    await harness.vm.retry();

    final state = harness.container.read(homeViewModelProvider);
    expect(state, isA<HomeLoaded>());
    expect((state as HomeLoaded).items.single, _itemA);
  });

  test('successful refresh replaces featured items', () async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    final harness = await createHarness();
    await harness.vm.load();

    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemB]));
    await harness.vm.refresh();

    final state = harness.container.read(homeViewModelProvider);
    expect(state, isA<HomeLoaded>());
    final loaded = state as HomeLoaded;
    expect(loaded.items, [_itemB]);
    expect(loaded.refreshFeedback, isNull);
  });

  test(
    'refresh failure preserves content and exposes consumable feedback',
    () async {
      when(
        () => repository.getDashboardItems(),
      ).thenAnswer((_) async => const Success([_itemA, _itemB]));

      final harness = await createHarness();
      await harness.vm.load();

      when(() => repository.getDashboardItems()).thenAnswer(
        (_) async => const Failure(DatabaseException('refresh sql explode')),
      );
      await harness.vm.refresh();

      final afterRefresh = harness.container.read(homeViewModelProvider);
      expect(afterRefresh, isA<HomeLoaded>());
      final loaded = afterRefresh as HomeLoaded;
      expect(loaded.items, [_itemA, _itemB]);
      expect(loaded.refreshFeedback, HomeUiMessages.refreshFailed);
      expect(loaded.refreshFeedback, isNot(contains('sql')));

      harness.vm.clearRefreshFeedback();
      final afterClear = harness.container.read(homeViewModelProvider);
      expect(afterClear, isA<HomeLoaded>());
      final cleared = afterClear as HomeLoaded;
      expect(cleared.refreshFeedback, isNull);
      expect(cleared.items, [_itemA, _itemB]);
    },
  );

  test('duplicate refresh is ignored while one is in flight', () async {
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) async => const Success([_itemA]));

    final harness = await createHarness();
    await harness.vm.load();
    clearInteractions(repository);

    final completer = Completer<Result<List<DashboardItem>>>();
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) => completer.future);

    final first = harness.vm.refresh();
    final second = harness.vm.refresh();
    completer.complete(const Success([_itemB]));
    await Future.wait([first, second]);

    verify(() => repository.getDashboardItems()).called(1);
    final state = harness.container.read(homeViewModelProvider) as HomeLoaded;
    expect(state.items, [_itemB]);
  });

  test('disposed view model does not commit late async results', () async {
    final completer = Completer<Result<List<DashboardItem>>>();
    when(
      () => repository.getDashboardItems(),
    ).thenAnswer((_) => completer.future);

    final container = await createTestContainer(
      overrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    final subscription = container.listen(
      homeViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    expect(container.read(homeViewModelProvider), isA<HomeLoading>());

    subscription.close();
    container.dispose();

    completer.complete(const Success([_itemA]));
    await Future<void>.delayed(Duration.zero);
  });
}
