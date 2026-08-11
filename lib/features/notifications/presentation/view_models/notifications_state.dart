import 'dart:collection';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:meta/meta.dart';

/// Sanitized Vietnamese copy for notifications UI — never raw backend/SQL text.
abstract final class NotificationsUiMessages {
  static const unauthenticated =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const network = 'Không thể kết nối. Vui lòng thử lại.';
  static const loadFailed = 'Không tải được thông báo. Vui lòng thử lại.';
  static const loadMoreFailed = 'Không tải thêm thông báo. Vui lòng thử lại.';
  static const refreshFailed =
      'Không làm mới được thông báo. Vui lòng thử lại.';
  static const markReadFailed = 'Không đánh dấu đã đọc được. Vui lòng thử lại.';
  static const markAllReadFailed =
      'Không đánh dấu tất cả đã đọc được. Vui lòng thử lại.';
  static const empty = 'Chưa có thông báo nào';
}

/// Maps repository [AppException]s to sanitized UI copy.
abstract final class NotificationsFailureMapper {
  static String mapLoadFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => NotificationsUiMessages.unauthenticated,
      NetworkException() => NotificationsUiMessages.network,
      _ => NotificationsUiMessages.loadFailed,
    };
  }

  static String mapLoadMoreFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => NotificationsUiMessages.unauthenticated,
      NetworkException() => NotificationsUiMessages.network,
      _ => NotificationsUiMessages.loadMoreFailed,
    };
  }

  static String mapRefreshFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => NotificationsUiMessages.unauthenticated,
      NetworkException() => NotificationsUiMessages.network,
      _ => NotificationsUiMessages.refreshFailed,
    };
  }

  static String mapMarkReadFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => NotificationsUiMessages.unauthenticated,
      NetworkException() => NotificationsUiMessages.network,
      _ => NotificationsUiMessages.markReadFailed,
    };
  }

  static String mapMarkAllReadFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => NotificationsUiMessages.unauthenticated,
      NetworkException() => NotificationsUiMessages.network,
      _ => NotificationsUiMessages.markAllReadFailed,
    };
  }
}

sealed class NotificationsState {
  const NotificationsState();
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

@immutable
final class NotificationsFailure extends NotificationsState {
  const NotificationsFailure(this.message);

  final String message;
}

/// Empty or populated list content with pagination and mutation flags.
@immutable
final class NotificationsContent extends NotificationsState {
  NotificationsContent({
    required List<AppNotification> items,
    required this.currentPage,
    required this.hasMore,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    Set<String> markingReadIds = const {},
    this.isMarkingAllRead = false,
    this.actionFeedback,
    this.paginationError,
  }) : items = UnmodifiableListView(items),
       markingReadIds = UnmodifiableSetView(Set<String>.from(markingReadIds));

  final UnmodifiableListView<AppNotification> items;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final UnmodifiableSetView<String> markingReadIds;
  final bool isMarkingAllRead;
  final String? actionFeedback;
  final String? paginationError;

  bool get isEmpty => items.isEmpty;

  bool get hasUnread => items.any((notification) => !notification.isRead);

  NotificationsContent copyWith({
    List<AppNotification>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    Set<String>? markingReadIds,
    bool? isMarkingAllRead,
    String? actionFeedback,
    String? paginationError,
    bool clearActionFeedback = false,
    bool clearPaginationError = false,
  }) {
    return NotificationsContent(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      markingReadIds: markingReadIds ?? this.markingReadIds,
      isMarkingAllRead: isMarkingAllRead ?? this.isMarkingAllRead,
      actionFeedback: clearActionFeedback
          ? null
          : actionFeedback ?? this.actionFeedback,
      paginationError: clearPaginationError
          ? null
          : paginationError ?? this.paginationError,
    );
  }
}
