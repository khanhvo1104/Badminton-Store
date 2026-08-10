import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/favorites/data/repositories/supabase_favorite_repository.dart';
import 'package:base_project/features/favorites/domain/entities/favorite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _productId = '22222222-2222-4222-8222-222222222222';
const _otherProductId = '33333333-3333-4333-8333-333333333333';
const _createdAt = '2026-08-10T10:00:00.000Z';

Map<String, dynamic> _favoriteRow({
  String userId = _userId,
  String productId = _productId,
  String? createdAt = _createdAt,
}) {
  return <String, dynamic>{
    'user_id': userId,
    'product_id': productId,
    if (createdAt != null) 'created_at': createdAt,
  };
}

Never _unusedSeam() => throw StateError('database seam must not be invoked');

SupabaseFavoriteRepository _repo({
  String? Function()? currentUserId,
  FavoriteUpsertQuery? upsert,
  FavoriteDeleteQuery? delete,
  FavoriteContainsQuery? contains,
  FavoriteListQuery? list,
}) {
  return SupabaseFavoriteRepository.testing(
    currentUserId: currentUserId ?? (() => _userId),
    upsert:
        upsert ??
        (({
          required String table,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
    delete:
        delete ??
        (({
          required String table,
          required String userId,
          required String productId,
        }) async => _unusedSeam()),
    contains:
        contains ??
        (({
          required String table,
          required String selectColumns,
          required String userId,
          required String productId,
        }) async => _unusedSeam()),
    list:
        list ??
        (({
          required String table,
          required String userId,
          required String orderColumn,
          required bool ascending,
        }) async => _unusedSeam()),
  );
}

void main() {
  group('unauthenticated boundary', () {
    test('add returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        upsert:
            ({
              required String table,
              required Map<String, Object?> values,
            }) async {
              seamCalls++;
              return _favoriteRow();
            },
      );

      final result = await repo.add(_productId);

      expect(seamCalls, 0);
      expect(result, isA<Failure<Favorite>>());
      expect((result as Failure<Favorite>).error, isA<UnauthorizedException>());
      expect(result.error.message, 'Please sign in to manage favorites');
    });

    test('remove returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        delete:
            ({
              required String table,
              required String userId,
              required String productId,
            }) async {
              seamCalls++;
            },
      );

      final result = await repo.remove(_productId);

      expect(seamCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<UnauthorizedException>());
    });

    test('contains returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        contains:
            ({
              required String table,
              required String selectColumns,
              required String userId,
              required String productId,
            }) async {
              seamCalls++;
              return null;
            },
      );

      final result = await repo.contains(_productId);

      expect(seamCalls, 0);
      expect(result, isA<Failure<bool>>());
      expect((result as Failure<bool>).error, isA<UnauthorizedException>());
    });

    test('list returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
            }) async {
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list();

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<Favorite>>>());
      expect(
        (result as Failure<List<Favorite>>).error,
        isA<UnauthorizedException>(),
      );
    });
  });

  group('add', () {
    test('targets favorites with auth user_id and product_id', () async {
      late String capturedTable;
      late Map<String, Object?> capturedValues;

      final repo = _repo(
        upsert:
            ({
              required String table,
              required Map<String, Object?> values,
            }) async {
              capturedTable = table;
              capturedValues = Map<String, Object?>.from(values);
              return _favoriteRow();
            },
      );

      final result = await repo.add(_productId);

      expect(capturedTable, 'favorites');
      expect(capturedValues.keys.toSet(), {'user_id', 'product_id'});
      expect(capturedValues['user_id'], _userId);
      expect(capturedValues['product_id'], _productId);
      expect(result, isA<Success<Favorite>>());
      final favorite = (result as Success<Favorite>).data;
      expect(favorite.id, '$_userId:$_productId');
      expect(favorite.userId, _userId);
      expect(favorite.productId, _productId);
      expect(favorite.createdAt, DateTime.parse(_createdAt));
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        upsert:
            ({
              required String table,
              required Map<String, Object?> values,
            }) async {
              throw const PostgrestException(
                message: 'upsert failed',
                code: '23505',
              );
            },
      );

      final result = await repo.add(_productId);

      expect(result, isA<Failure<Favorite>>());
      final error = (result as Failure<Favorite>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '23505');
      expect(error.message, 'upsert failed');
    });
  });

  group('remove', () {
    test('restricts delete by authenticated user and product', () async {
      late String capturedTable;
      late String capturedUserId;
      late String capturedProductId;

      final repo = _repo(
        delete:
            ({
              required String table,
              required String userId,
              required String productId,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedProductId = productId;
            },
      );

      final result = await repo.remove(_productId);

      expect(capturedTable, 'favorites');
      expect(capturedUserId, _userId);
      expect(capturedProductId, _productId);
      expect(result, isA<Success<void>>());
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        delete:
            ({
              required String table,
              required String userId,
              required String productId,
            }) async {
              throw const PostgrestException(
                message: 'delete failed',
                code: '42501',
              );
            },
      );

      final result = await repo.remove(_productId);

      expect(result, isA<Failure<void>>());
      final error = (result as Failure<void>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42501');
    });
  });

  group('contains', () {
    test('selects product_id and filters by user + product', () async {
      late String capturedTable;
      late String capturedSelect;
      late String capturedUserId;
      late String capturedProductId;

      final repo = _repo(
        contains:
            ({
              required String table,
              required String selectColumns,
              required String userId,
              required String productId,
            }) async {
              capturedTable = table;
              capturedSelect = selectColumns;
              capturedUserId = userId;
              capturedProductId = productId;
              return {'product_id': productId};
            },
      );

      final present = await repo.contains(_productId);

      expect(capturedTable, 'favorites');
      expect(capturedSelect, 'product_id');
      expect(capturedUserId, _userId);
      expect(capturedProductId, _productId);
      expect(present, isA<Success<bool>>());
      expect((present as Success<bool>).data, isTrue);

      final missingRepo = _repo(
        contains:
            ({
              required String table,
              required String selectColumns,
              required String userId,
              required String productId,
            }) async => null,
      );
      final missing = await missingRepo.contains(_otherProductId);
      expect((missing as Success<bool>).data, isFalse);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        contains:
            ({
              required String table,
              required String selectColumns,
              required String userId,
              required String productId,
            }) async {
              throw const PostgrestException(
                message: 'contains failed',
                code: 'PGRST116',
              );
            },
      );

      final result = await repo.contains(_productId);

      expect(result, isA<Failure<bool>>());
      expect(
        ((result as Failure<bool>).error as DatabaseException).code,
        'PGRST116',
      );
    });
  });

  group('list', () {
    test('filters by user, orders by created_at desc, maps fields', () async {
      late String capturedTable;
      late String capturedUserId;
      late String capturedOrder;
      late bool capturedAscending;

      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedOrder = orderColumn;
              capturedAscending = ascending;
              return [
                _favoriteRow(productId: _otherProductId),
                _favoriteRow()..remove('created_at'),
              ];
            },
      );

      final result = await repo.list();

      expect(capturedTable, 'favorites');
      expect(capturedUserId, _userId);
      expect(capturedOrder, 'created_at');
      expect(capturedAscending, isFalse);
      expect(result, isA<Success<List<Favorite>>>());
      final favorites = (result as Success<List<Favorite>>).data;
      expect(favorites, hasLength(2));
      expect(favorites[0].id, '$_userId:$_otherProductId');
      expect(favorites[0].userId, _userId);
      expect(favorites[0].productId, _otherProductId);
      expect(favorites[0].createdAt, DateTime.parse(_createdAt));
      expect(favorites[1].id, '$_userId:$_productId');
      expect(favorites[1].createdAt, isNull);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
            }) async {
              throw const PostgrestException(
                message: 'list failed',
                code: '42P01',
              );
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<Favorite>>>());
      expect(
        ((result as Failure<List<Favorite>>).error as DatabaseException).code,
        '42P01',
      );
    });
  });
}
