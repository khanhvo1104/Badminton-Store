import 'package:base_project/core/constants/pagination_constants.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/notifications/di/notifications_providers.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:base_project/features/notifications/presentation/view_models/notifications_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

class NotificationsViewModel extends StateNotifier<NotificationsState> {
  NotificationsViewModel(this._ref) : super(const NotificationsLoading()) {
    load();
  }

  final Ref _ref;

  static const int pageSize = PaginationConstants.defaultPageSize;

  int _loadGeneration = 0;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = const NotificationsLoading();

    final result = await _ref
        .read(notificationRepositoryProvider)
        .list(page: PaginationConstants.firstPage, pageSize: pageSize);

    if (!_canCommit(generation)) {
      return;
    }

    state = switch (result) {
      Success(data: final items) => NotificationsContent(
        items: items,
        currentPage: PaginationConstants.firstPage,
        hasMore: items.length >= pageSize,
      ),
      Failure(error: final error) => NotificationsFailure(
        NotificationsFailureMapper.mapLoadFailure(error),
      ),
    };
  }

  Future<void> retry() => load();

  Future<void> refresh() async {
    final current = state;
    if (current is! NotificationsContent) {
      return load();
    }
    if (current.isRefreshing) {
      return;
    }

    final generation = ++_loadGeneration;
    state = current.copyWith(
      isRefreshing: true,
      isLoadingMore: false,
      clearActionFeedback: true,
      clearPaginationError: true,
    );

    final result = await _ref
        .read(notificationRepositoryProvider)
        .list(page: PaginationConstants.firstPage, pageSize: pageSize);

    if (!_canCommit(generation)) {
      return;
    }

    final latest = state;
    if (latest is! NotificationsContent) {
      return;
    }

    switch (result) {
      case Success(data: final items):
        state = NotificationsContent(
          items: items,
          currentPage: PaginationConstants.firstPage,
          hasMore: items.length >= pageSize,
        );
      case Failure(error: final error):
        state = latest.copyWith(
          isRefreshing: false,
          actionFeedback: NotificationsFailureMapper.mapRefreshFailure(error),
        );
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! NotificationsContent) {
      return;
    }
    if (!current.hasMore ||
        current.isLoadingMore ||
        current.isRefreshing ||
        current.isEmpty) {
      return;
    }

    final generation = _loadGeneration;
    final nextPage = current.currentPage + 1;
    state = current.copyWith(isLoadingMore: true, clearPaginationError: true);

    final result = await _ref
        .read(notificationRepositoryProvider)
        .list(page: nextPage, pageSize: pageSize);

    if (!_canCommit(generation)) {
      return;
    }

    final latest = state;
    if (latest is! NotificationsContent) {
      return;
    }

    switch (result) {
      case Success(data: final page):
        state = latest.copyWith(
          items: _appendUnique(latest.items, page),
          currentPage: nextPage,
          hasMore: page.length >= pageSize,
          isLoadingMore: false,
        );
      case Failure(error: final error):
        state = latest.copyWith(
          isLoadingMore: false,
          paginationError: NotificationsFailureMapper.mapLoadMoreFailure(error),
        );
    }
  }

  Future<void> markRead(String id) async {
    final current = state;
    if (current is! NotificationsContent) {
      return;
    }
    if (current.markingReadIds.contains(id)) {
      return;
    }

    AppNotification? target;
    for (final notification in current.items) {
      if (notification.id == id) {
        target = notification;
        break;
      }
    }
    if (target == null || target.isRead) {
      return;
    }

    state = current.copyWith(
      markingReadIds: {...current.markingReadIds, id},
      clearActionFeedback: true,
    );

    final result = await _ref.read(notificationRepositoryProvider).markRead(id);

    if (!mounted) {
      return;
    }

    final latest = state;
    if (latest is! NotificationsContent) {
      return;
    }

    final nextIds = Set<String>.from(latest.markingReadIds)..remove(id);

    switch (result) {
      case Success():
        state = latest.copyWith(
          items: [
            for (final notification in latest.items)
              if (notification.id == id)
                notification.copyWith(isRead: true)
              else
                notification,
          ],
          markingReadIds: nextIds,
        );
      case Failure(error: final error):
        state = latest.copyWith(
          markingReadIds: nextIds,
          actionFeedback: NotificationsFailureMapper.mapMarkReadFailure(error),
        );
    }
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is! NotificationsContent) {
      return;
    }
    if (current.isMarkingAllRead || !current.hasUnread) {
      return;
    }

    state = current.copyWith(isMarkingAllRead: true, clearActionFeedback: true);

    final result = await _ref
        .read(notificationRepositoryProvider)
        .markAllRead();

    if (!mounted) {
      return;
    }

    final latest = state;
    if (latest is! NotificationsContent) {
      return;
    }

    switch (result) {
      case Success():
        state = latest.copyWith(
          items: [
            for (final notification in latest.items)
              notification.copyWith(isRead: true),
          ],
          isMarkingAllRead: false,
        );
      case Failure(error: final error):
        state = latest.copyWith(
          isMarkingAllRead: false,
          actionFeedback: NotificationsFailureMapper.mapMarkAllReadFailure(
            error,
          ),
        );
    }
  }

  void clearActionFeedback() {
    final current = state;
    if (current is NotificationsContent && current.actionFeedback != null) {
      state = current.copyWith(clearActionFeedback: true);
    }
  }

  bool _canCommit(int generation) => mounted && generation == _loadGeneration;

  @visibleForTesting
  static List<AppNotification> appendUniqueForTest(
    List<AppNotification> existing,
    List<AppNotification> page,
  ) => _appendUnique(existing, page);

  @visibleForTesting
  static String mapLoadFailure(AppException error) =>
      NotificationsFailureMapper.mapLoadFailure(error);

  static List<AppNotification> _appendUnique(
    List<AppNotification> existing,
    List<AppNotification> page,
  ) {
    final seen = {for (final item in existing) item.id};
    final merged = List<AppNotification>.of(existing);
    for (final item in page) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }
    return merged;
  }
}

final notificationsViewModelProvider =
    StateNotifierProvider.autoDispose<
      NotificationsViewModel,
      NotificationsState
    >((ref) {
      return NotificationsViewModel(ref);
    });
