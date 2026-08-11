import 'dart:collection';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:meta/meta.dart';

/// Sanitized Home UI copy — never raw backend/SQL/exception text.
abstract final class HomeUiMessages {
  static const unauthenticated =
      'Your session has expired. Please sign in again.';
  static const network = 'Unable to connect. Please try again.';
  static const loadFailed =
      'Unable to load featured products. Please try again.';
  static const refreshFailed =
      'Unable to refresh featured products. Please try again.';
  static const loading = 'Loading featured products...';
  static const subtitle =
      'Discover featured badminton gear for your next game.';
  static const featuredSection = 'Featured products';
  static const emptyTitle = 'No featured products';
  static const emptyMessage = 'Browse the catalog to discover badminton gear.';
  static const browseCatalog = 'Browse catalog';
  static const search = 'Search';
  static const catalogAction = 'Catalog';
  static const searchAction = 'Search';
}

/// Maps repository [AppException]s to sanitized UI copy.
abstract final class HomeFailureMapper {
  static String mapLoadFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => HomeUiMessages.unauthenticated,
      NetworkException() => HomeUiMessages.network,
      _ => HomeUiMessages.loadFailed,
    };
  }

  static String mapRefreshFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => HomeUiMessages.unauthenticated,
      NetworkException() => HomeUiMessages.network,
      _ => HomeUiMessages.refreshFailed,
    };
  }
}

sealed class HomeState {
  const HomeState();
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

@immutable
final class HomeLoaded extends HomeState {
  HomeLoaded(
    List<DashboardItem> items, {
    this.isRefreshing = false,
    this.refreshFeedback,
  }) : items = UnmodifiableListView(items);

  final UnmodifiableListView<DashboardItem> items;
  final bool isRefreshing;
  final String? refreshFeedback;

  HomeLoaded copyWith({
    List<DashboardItem>? items,
    bool? isRefreshing,
    String? refreshFeedback,
    bool clearRefreshFeedback = false,
  }) {
    return HomeLoaded(
      items ?? this.items,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFeedback: clearRefreshFeedback
          ? null
          : refreshFeedback ?? this.refreshFeedback,
    );
  }
}

@immutable
final class HomeEmpty extends HomeState {
  const HomeEmpty({this.isRefreshing = false, this.refreshFeedback});

  final bool isRefreshing;
  final String? refreshFeedback;

  HomeEmpty copyWith({
    bool? isRefreshing,
    String? refreshFeedback,
    bool clearRefreshFeedback = false,
  }) {
    return HomeEmpty(
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFeedback: clearRefreshFeedback
          ? null
          : refreshFeedback ?? this.refreshFeedback,
    );
  }
}

@immutable
final class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;
}
