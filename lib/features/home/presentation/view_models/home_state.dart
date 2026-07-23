import 'dart:collection';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';

sealed class HomeState {
  const HomeState();
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  HomeLoaded(List<DashboardItem> items) : items = UnmodifiableListView(items);

  final UnmodifiableListView<DashboardItem> items;
}

final class HomeEmpty extends HomeState {
  const HomeEmpty();
}

final class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;
}
