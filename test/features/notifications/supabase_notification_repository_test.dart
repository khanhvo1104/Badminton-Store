import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/notifications/data/repositories/supabase_notification_repository.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _notificationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _otherNotificationId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _createdAt = '2026-08-10T10:00:00.000Z';

Never _unusedSeam() => throw StateError('database seam must not be invoked');

Map<String, dynamic> _notificationRow({
  String id = _notificationId,
  String userId = _userId,
  String title = 'Order shipped',
  String body = 'Your order is on the way.',
  String type = 'order_update',
  bool isRead = false,
  Map<String, dynamic>? payload,
  Object? createdAt = _createdAt,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'body': body,
    'type': type,
    'is_read': isRead,
    'payload': payload ?? const <String, dynamic>{'order_id': 'ord-1'},
    'created_at': createdAt,
  };
}

SupabaseNotificationRepository _repo({
  String? Function()? currentUserId,
  NotificationListQuery? list,
  NotificationUnreadCountQuery? unreadCount,
  NotificationMarkReadQuery? markRead,
  NotificationMarkAllReadQuery? markAllRead,
}) {
  return SupabaseNotificationRepository.testing(
    currentUserId: currentUserId ?? (() => _userId),
    list:
        list ??
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
        }) async => _unusedSeam()),
    unreadCount:
        unreadCount ??
        (({
          required String table,
          required String userId,
          required bool isRead,
          required CountOption countOption,
        }) async => _unusedSeam()),
    markRead:
        markRead ??
        (({
          required String table,
          required String userId,
          required String notificationId,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
    markAllRead:
        markAllRead ??
        (({
          required String table,
          required String userId,
          required bool isRead,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
  );
}

void main() {
  group('unauthenticated boundary', () {
    test('list returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        list:
            ({
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
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list();

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<AppNotification>>>());
      expect(
        (result as Failure<List<AppNotification>>).error,
        isA<UnauthorizedException>(),
      );
      expect(result.error.message, 'Please sign in to manage notifications');
    });

    test('unreadCount returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        unreadCount:
            ({
              required String table,
              required String userId,
              required bool isRead,
              required CountOption countOption,
            }) async {
              seamCalls++;
              return 0;
            },
      );

      final result = await repo.unreadCount();

      expect(seamCalls, 0);
      expect(result, isA<Failure<int>>());
      expect((result as Failure<int>).error, isA<UnauthorizedException>());
    });

    test('markRead returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        markRead:
            ({
              required String table,
              required String userId,
              required String notificationId,
              required Map<String, Object?> values,
            }) async {
              seamCalls++;
            },
      );

      final result = await repo.markRead(_notificationId);

      expect(seamCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<UnauthorizedException>());
    });

    test('markAllRead returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        markAllRead:
            ({
              required String table,
              required String userId,
              required bool isRead,
              required Map<String, Object?> values,
            }) async {
              seamCalls++;
            },
      );

      final result = await repo.markAllRead();

      expect(seamCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<UnauthorizedException>());
    });
  });

  group('list pagination validation', () {
    test('page < 1 returns ValidationException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        list:
            ({
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
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list(page: 0, pageSize: 20);

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<AppNotification>>>());
      expect(
        (result as Failure<List<AppNotification>>).error,
        isA<ValidationException>(),
      );
    });

    test('pageSize < 1 returns ValidationException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        list:
            ({
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
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list(page: 1, pageSize: 0);

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<AppNotification>>>());
      expect(
        (result as Failure<List<AppNotification>>).error,
        isA<ValidationException>(),
      );
    });
  });

  group('list', () {
    test(
      'scopes by user_id, uses projection, dual newest-first order, inclusive range',
      () async {
        late String capturedTable;
        late String capturedSelect;
        late String capturedUserId;
        late String capturedPrimaryOrder;
        late bool capturedPrimaryAscending;
        late String capturedSecondaryOrder;
        late bool capturedSecondaryAscending;
        late int capturedFrom;
        late int capturedTo;

        final repo = _repo(
          list:
              ({
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
                capturedTable = table;
                capturedSelect = selectColumns;
                capturedUserId = userId;
                capturedPrimaryOrder = primaryOrderColumn;
                capturedPrimaryAscending = primaryAscending;
                capturedSecondaryOrder = secondaryOrderColumn;
                capturedSecondaryAscending = secondaryAscending;
                capturedFrom = from;
                capturedTo = to;
                return [
                  _notificationRow(),
                  _notificationRow(
                    id: _otherNotificationId,
                    type: 'promotion',
                    title: 'Sale',
                    body: 'Rackets on sale',
                    isRead: true,
                    payload: const <String, dynamic>{},
                    createdAt: null,
                  ),
                ];
              },
        );

        final result = await repo.list(page: 2, pageSize: 10);

        expect(capturedTable, 'notifications');
        expect(capturedSelect, notificationSelectColumns);
        expect(
          capturedSelect,
          'id,user_id,title,body,type,is_read,payload,created_at',
        );
        expect(capturedUserId, _userId);
        expect(capturedPrimaryOrder, 'created_at');
        expect(capturedPrimaryAscending, isFalse);
        expect(capturedSecondaryOrder, 'id');
        expect(capturedSecondaryAscending, isFalse);
        expect(capturedFrom, 10);
        expect(capturedTo, 19);

        expect(result, isA<Success<List<AppNotification>>>());
        final items = (result as Success<List<AppNotification>>).data;
        expect(items, hasLength(2));

        expect(items[0].id, _notificationId);
        expect(items[0].userId, _userId);
        expect(items[0].title, 'Order shipped');
        expect(items[0].body, 'Your order is on the way.');
        expect(items[0].type, NotificationType.orderUpdate);
        expect(items[0].isRead, isFalse);
        expect(items[0].payload, {'order_id': 'ord-1'});
        expect(items[0].createdAt, DateTime.parse(_createdAt).toUtc());
        expect(items[0].createdAt!.isUtc, isTrue);

        expect(items[1].id, _otherNotificationId);
        expect(items[1].type, NotificationType.promotion);
        expect(items[1].isRead, isTrue);
        expect(items[1].payload, isEmpty);
        expect(items[1].createdAt, isNull);
      },
    );

    test('page 1 pageSize 20 uses inclusive range 0..19', () async {
      late int capturedFrom;
      late int capturedTo;

      final repo = _repo(
        list:
            ({
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
              capturedFrom = from;
              capturedTo = to;
              return const [];
            },
      );

      final result = await repo.list();

      expect(capturedFrom, 0);
      expect(capturedTo, 19);
      expect(result, isA<Success<List<AppNotification>>>());
      expect((result as Success<List<AppNotification>>).data, isEmpty);
    });

    test('maps all four database type values', () async {
      final repo = _repo(
        list:
            ({
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
              return [
                _notificationRow(id: '1', type: 'order_update'),
                _notificationRow(id: '2', type: 'promotion'),
                _notificationRow(id: '3', type: 'system'),
                _notificationRow(id: '4', type: 'stock_alert'),
              ];
            },
      );

      final result = await repo.list();

      expect(result, isA<Success<List<AppNotification>>>());
      final types = (result as Success<List<AppNotification>>).data
          .map((item) => item.type)
          .toList(growable: false);
      expect(types, [
        NotificationType.orderUpdate,
        NotificationType.promotion,
        NotificationType.system,
        NotificationType.stockAlert,
      ]);
    });

    test('unknown type returns DatabaseException without type error', () async {
      final repo = _repo(
        list:
            ({
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
              return [_notificationRow(type: 'mystery')];
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<AppNotification>>>());
      expect(
        (result as Failure<List<AppNotification>>).error,
        isA<DatabaseException>(),
      );
      expect(result.error.message, contains('Unsupported notification type'));
    });

    test('missing required field returns DatabaseException', () async {
      final repo = _repo(
        list:
            ({
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
              return [_notificationRow()..remove('title')];
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<AppNotification>>>());
      final error = (result as Failure<List<AppNotification>>).error;
      expect(error, isA<DatabaseException>());
      expect(error.message, 'Missing required field: title');
    });

    test('non-string payload values return DatabaseException', () async {
      final repo = _repo(
        list:
            ({
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
              return [
                _notificationRow(payload: <String, dynamic>{'order_id': 42}),
              ];
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<AppNotification>>>());
      expect(
        (result as Failure<List<AppNotification>>).error,
        isA<DatabaseException>(),
      );
      expect(result.error.message, 'Invalid notification payload');
    });

    test('non-map payload returns DatabaseException', () async {
      final repo = _repo(
        list:
            ({
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
              final row = _notificationRow();
              row['payload'] = 'oops';
              return [row];
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<AppNotification>>>());
      expect(
        (result as Failure<List<AppNotification>>).error,
        isA<DatabaseException>(),
      );
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        list:
            ({
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
              throw const PostgrestException(
                message: 'list failed',
                code: '42501',
              );
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<AppNotification>>>());
      final error = (result as Failure<List<AppNotification>>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42501');
      expect(error.message, 'list failed');
    });
  });

  group('unreadCount', () {
    test(
      'scopes to user_id and is_read=false with exact count option',
      () async {
        late String capturedTable;
        late String capturedUserId;
        late bool capturedIsRead;
        late CountOption capturedOption;

        final repo = _repo(
          unreadCount:
              ({
                required String table,
                required String userId,
                required bool isRead,
                required CountOption countOption,
              }) async {
                capturedTable = table;
                capturedUserId = userId;
                capturedIsRead = isRead;
                capturedOption = countOption;
                return 3;
              },
        );

        final result = await repo.unreadCount();

        expect(capturedTable, 'notifications');
        expect(capturedUserId, _userId);
        expect(capturedIsRead, isFalse);
        expect(capturedOption, CountOption.exact);
        expect(result, isA<Success<int>>());
        expect((result as Success<int>).data, 3);
      },
    );

    test('returns zero safely for empty unread set', () async {
      final repo = _repo(
        unreadCount:
            ({
              required String table,
              required String userId,
              required bool isRead,
              required CountOption countOption,
            }) async {
              return 0;
            },
      );

      final result = await repo.unreadCount();

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).data, 0);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        unreadCount:
            ({
              required String table,
              required String userId,
              required bool isRead,
              required CountOption countOption,
            }) async {
              throw const PostgrestException(
                message: 'count failed',
                code: '42P01',
              );
            },
      );

      final result = await repo.unreadCount();

      expect(result, isA<Failure<int>>());
      final error = (result as Failure<int>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42P01');
    });
  });

  group('markRead', () {
    test('rejects blank id without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        markRead:
            ({
              required String table,
              required String userId,
              required String notificationId,
              required Map<String, Object?> values,
            }) async {
              seamCalls++;
            },
      );

      final result = await repo.markRead('   ');

      expect(seamCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<ValidationException>());
    });

    test('scopes update to owner + id and sends only is_read: true', () async {
      late String capturedTable;
      late String capturedUserId;
      late String capturedId;
      late Map<String, Object?> capturedValues;

      final repo = _repo(
        markRead:
            ({
              required String table,
              required String userId,
              required String notificationId,
              required Map<String, Object?> values,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedId = notificationId;
              capturedValues = values;
            },
      );

      final result = await repo.markRead(_notificationId);

      expect(capturedTable, 'notifications');
      expect(capturedUserId, _userId);
      expect(capturedId, _notificationId);
      expect(capturedValues, const {'is_read': true});
      expect(capturedValues.keys, ['is_read']);
      expect(result, isA<Success<void>>());
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        markRead:
            ({
              required String table,
              required String userId,
              required String notificationId,
              required Map<String, Object?> values,
            }) async {
              throw const PostgrestException(
                message: 'update failed',
                code: '42501',
              );
            },
      );

      final result = await repo.markRead(_notificationId);

      expect(result, isA<Failure<void>>());
      final error = (result as Failure<void>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42501');
    });
  });

  group('markAllRead', () {
    test('scopes to owner and unread rows, sends only is_read: true', () async {
      late String capturedTable;
      late String capturedUserId;
      late bool capturedIsRead;
      late Map<String, Object?> capturedValues;

      final repo = _repo(
        markAllRead:
            ({
              required String table,
              required String userId,
              required bool isRead,
              required Map<String, Object?> values,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedIsRead = isRead;
              capturedValues = values;
            },
      );

      final result = await repo.markAllRead();

      expect(capturedTable, 'notifications');
      expect(capturedUserId, _userId);
      expect(capturedIsRead, isFalse);
      expect(capturedValues, const {'is_read': true});
      expect(capturedValues.keys, ['is_read']);
      expect(result, isA<Success<void>>());
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        markAllRead:
            ({
              required String table,
              required String userId,
              required bool isRead,
              required Map<String, Object?> values,
            }) async {
              throw const PostgrestException(
                message: 'bulk update failed',
                code: 'PGRST301',
              );
            },
      );

      final result = await repo.markAllRead();

      expect(result, isA<Failure<void>>());
      final error = (result as Failure<void>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, 'PGRST301');
    });
  });
}
