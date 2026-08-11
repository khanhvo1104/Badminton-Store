import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Explicit projection for notification history rows.
@visibleForTesting
const notificationSelectColumns =
    'id,user_id,title,body,type,is_read,payload,created_at';

/// Lists owner-scoped notification rows with dual order and inclusive range.
@visibleForTesting
typedef NotificationListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String selectColumns,
      required String userId,
      required String primaryOrderColumn,
      required bool primaryAscending,
      required String secondaryOrderColumn,
      required bool secondaryAscending,
      required int from,
      required int to,
    });

/// Counts owner-scoped rows with exact-count semantics (no body download).
@visibleForTesting
typedef NotificationUnreadCountQuery =
    Future<int> Function({
      required String table,
      required String userId,
      required bool isRead,
      required CountOption countOption,
    });

/// Marks a single owner-scoped notification as read.
@visibleForTesting
typedef NotificationMarkReadQuery =
    Future<void> Function({
      required String table,
      required String userId,
      required String notificationId,
      required Map<String, Object?> values,
    });

/// Marks all unread owner-scoped notifications as read.
@visibleForTesting
typedef NotificationMarkAllReadQuery =
    Future<void> Function({
      required String table,
      required String userId,
      required bool isRead,
      required Map<String, Object?> values,
    });

final class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(SupabaseClient client)
    : _currentUserId = (() => client.auth.currentUser?.id),
      _list =
          (({
            required String table,
            required String selectColumns,
            required String userId,
            required String primaryOrderColumn,
            required bool primaryAscending,
            required String secondaryOrderColumn,
            required bool secondaryAscending,
            required int from,
            required int to,
          }) async {
            final rows = await client
                .from(table)
                .select(selectColumns)
                .eq('user_id', userId)
                .order(primaryOrderColumn, ascending: primaryAscending)
                .order(secondaryOrderColumn, ascending: secondaryAscending)
                .range(from, to);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }),
      _unreadCount =
          (({
            required String table,
            required String userId,
            required bool isRead,
            required CountOption countOption,
          }) async {
            return client
                .from(table)
                .count(countOption)
                .eq('user_id', userId)
                .eq('is_read', isRead);
          }),
      _markRead =
          (({
            required String table,
            required String userId,
            required String notificationId,
            required Map<String, Object?> values,
          }) async {
            await client
                .from(table)
                .update(values)
                .eq('user_id', userId)
                .eq('id', notificationId);
          }),
      _markAllRead =
          (({
            required String table,
            required String userId,
            required bool isRead,
            required Map<String, Object?> values,
          }) async {
            await client
                .from(table)
                .update(values)
                .eq('user_id', userId)
                .eq('is_read', isRead);
          });

  @visibleForTesting
  SupabaseNotificationRepository.testing({
    required String? Function() currentUserId,
    required NotificationListQuery list,
    required NotificationUnreadCountQuery unreadCount,
    required NotificationMarkReadQuery markRead,
    required NotificationMarkAllReadQuery markAllRead,
  }) : _currentUserId = currentUserId,
       _list = list,
       _unreadCount = unreadCount,
       _markRead = markRead,
       _markAllRead = markAllRead;

  final String? Function() _currentUserId;
  final NotificationListQuery _list;
  final NotificationUnreadCountQuery _unreadCount;
  final NotificationMarkReadQuery _markRead;
  final NotificationMarkAllReadQuery _markAllRead;

  @override
  Future<Result<List<AppNotification>>> list({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final userId = _requireUserId();
      if (page < 1 || pageSize < 1) {
        throw const ValidationException(
          'page and pageSize must be greater than or equal to 1',
        );
      }
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await _list(
        table: 'notifications',
        selectColumns: notificationSelectColumns,
        userId: userId,
        primaryOrderColumn: 'created_at',
        primaryAscending: false,
        secondaryOrderColumn: 'id',
        secondaryAscending: false,
        from: from,
        to: to,
      );
      return Success(rows.map(_mapNotification).toList(growable: false));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> markRead(String id) async {
    try {
      final userId = _requireUserId();
      if (id.trim().isEmpty) {
        throw const ValidationException('Notification id must not be blank');
      }
      await _markRead(
        table: 'notifications',
        userId: userId,
        notificationId: id,
        values: const {'is_read': true},
      );
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> markAllRead() async {
    try {
      final userId = _requireUserId();
      await _markAllRead(
        table: 'notifications',
        userId: userId,
        isRead: false,
        values: const {'is_read': true},
      );
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<int>> unreadCount() async {
    try {
      final userId = _requireUserId();
      final count = await _unreadCount(
        table: 'notifications',
        userId: userId,
        isRead: false,
        countOption: CountOption.exact,
      );
      return Success(count < 0 ? 0 : count);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  AppNotification _mapNotification(SupabaseRow row) {
    return AppNotification(
      id: requireString(row, 'id'),
      userId: requireString(row, 'user_id'),
      title: requireString(row, 'title'),
      body: requireString(row, 'body'),
      type: _mapType(requireString(row, 'type')),
      isRead: requireBool(row, 'is_read', fallback: false),
      payload: _mapPayload(row['payload']),
      createdAt: _mapCreatedAt(row['created_at']),
    );
  }

  NotificationType _mapType(String raw) {
    return switch (raw) {
      'order_update' => NotificationType.orderUpdate,
      'promotion' => NotificationType.promotion,
      'system' => NotificationType.system,
      'stock_alert' => NotificationType.stockAlert,
      _ => throw DatabaseException('Unsupported notification type: $raw'),
    };
  }

  Map<String, String>? _mapPayload(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw const DatabaseException('Invalid notification payload');
    }
    final mapped = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final entryValue = entry.value;
      if (key is! String) {
        throw const DatabaseException('Invalid notification payload');
      }
      if (entryValue == null) {
        throw const DatabaseException('Invalid notification payload');
      }
      if (entryValue is! String) {
        throw const DatabaseException('Invalid notification payload');
      }
      mapped[key] = entryValue;
    }
    return mapped;
  }

  DateTime? _mapCreatedAt(Object? value) {
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    return null;
  }

  String _requireUserId() {
    final userId = _currentUserId();
    if (userId == null) {
      throw const UnauthorizedException(
        'Please sign in to manage notifications',
      );
    }
    return userId;
  }
}
