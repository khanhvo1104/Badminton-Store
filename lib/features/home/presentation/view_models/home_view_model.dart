import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel(this._ref) : super(const HomeInitial()) {
    load();
  }

  final Ref _ref;

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    state = const HomeLoading();

    final result = await _ref.read(homeRepositoryProvider).getDashboardItems();

    if (!_canCommit(generation)) {
      return;
    }

    state = _mapFetchResult(result);
  }

  Future<void> retry() => load();

  Future<void> refresh() async {
    final current = state;
    if (current is HomeLoaded) {
      if (current.isRefreshing) {
        return;
      }
      final generation = ++_generation;
      state = current.copyWith(isRefreshing: true, clearRefreshFeedback: true);
      await _refreshWithGeneration(generation, previous: current);
      return;
    }

    if (current is HomeEmpty) {
      if (current.isRefreshing) {
        return;
      }
      final generation = ++_generation;
      state = current.copyWith(isRefreshing: true, clearRefreshFeedback: true);
      await _refreshWithGeneration(generation, previous: current);
      return;
    }

    await load();
  }

  Future<void> _refreshWithGeneration(
    int generation, {
    required HomeState previous,
  }) async {
    final result = await _ref.read(homeRepositoryProvider).getDashboardItems();

    if (!_canCommit(generation)) {
      return;
    }

    switch (result) {
      case Success(data: final items):
        state = items.isEmpty ? const HomeEmpty() : HomeLoaded(items);
      case Failure(error: final error):
        state = _mapRefreshFailure(previous, error);
    }
  }

  void clearRefreshFeedback() {
    final current = state;
    if (current is HomeLoaded && current.refreshFeedback != null) {
      state = current.copyWith(clearRefreshFeedback: true);
    } else if (current is HomeEmpty && current.refreshFeedback != null) {
      state = current.copyWith(clearRefreshFeedback: true);
    }
  }

  HomeState _mapFetchResult(Result<List<DashboardItem>> result) {
    return switch (result) {
      Success(data: final items) when items.isEmpty => const HomeEmpty(),
      Success(data: final items) => HomeLoaded(items),
      Failure(error: final error) => HomeError(
        HomeFailureMapper.mapLoadFailure(error),
      ),
    };
  }

  HomeState _mapRefreshFailure(HomeState previous, AppException error) {
    final message = HomeFailureMapper.mapRefreshFailure(error);
    return switch (previous) {
      HomeLoaded(:final items) => HomeLoaded(items, refreshFeedback: message),
      HomeEmpty() => HomeEmpty(refreshFeedback: message),
      _ => HomeError(HomeFailureMapper.mapLoadFailure(error)),
    };
  }

  bool _canCommit(int generation) => mounted && generation == _generation;

  @visibleForTesting
  static String mapLoadFailure(AppException error) =>
      HomeFailureMapper.mapLoadFailure(error);

  @visibleForTesting
  static String mapRefreshFailure(AppException error) =>
      HomeFailureMapper.mapRefreshFailure(error);
}

final homeViewModelProvider =
    StateNotifierProvider.autoDispose<HomeViewModel, HomeState>((ref) {
      return HomeViewModel(ref);
    });
