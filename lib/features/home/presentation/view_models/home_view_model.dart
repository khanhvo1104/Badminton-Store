import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel(this._ref) : super(const HomeInitial()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const HomeLoading();
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> retry() => load();

  Future<void> _fetch() async {
    final result = await _ref.read(homeRepositoryProvider).getDashboardItems();
    if (!mounted) {
      return;
    }

    state = switch (result) {
      Success(data: final items) when items.isEmpty => const HomeEmpty(),
      Success(data: final items) => HomeLoaded(items),
      Failure(error: final error) => HomeError(error.message),
    };
  }
}

final homeViewModelProvider =
    StateNotifierProvider.autoDispose<HomeViewModel, HomeState>((ref) {
      return HomeViewModel(ref);
    });
