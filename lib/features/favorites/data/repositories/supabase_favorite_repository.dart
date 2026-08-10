import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/favorites/domain/entities/favorite.dart';
import 'package:base_project/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upserts a favorite row and returns the selected result.
@visibleForTesting
typedef FavoriteUpsertQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required Map<String, Object?> values,
    });

/// Deletes a favorite row scoped to user + product.
@visibleForTesting
typedef FavoriteDeleteQuery =
    Future<void> Function({
      required String table,
      required String userId,
      required String productId,
    });

/// Looks up whether a favorite exists for user + product.
@visibleForTesting
typedef FavoriteContainsQuery =
    Future<Map<String, dynamic>?> Function({
      required String table,
      required String selectColumns,
      required String userId,
      required String productId,
    });

/// Lists favorite rows for a user with a single order column.
@visibleForTesting
typedef FavoriteListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String userId,
      required String orderColumn,
      required bool ascending,
    });

final class SupabaseFavoriteRepository implements FavoriteRepository {
  SupabaseFavoriteRepository(SupabaseClient client)
    : _currentUserId = (() => client.auth.currentUser?.id),
      _upsert =
          (({
            required String table,
            required Map<String, Object?> values,
          }) async {
            final row = await client
                .from(table)
                .upsert(values)
                .select()
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _delete =
          (({
            required String table,
            required String userId,
            required String productId,
          }) async {
            await client
                .from(table)
                .delete()
                .eq('user_id', userId)
                .eq('product_id', productId);
          }),
      _contains =
          (({
            required String table,
            required String selectColumns,
            required String userId,
            required String productId,
          }) async {
            final row = await client
                .from(table)
                .select(selectColumns)
                .eq('user_id', userId)
                .eq('product_id', productId)
                .maybeSingle();
            return row == null ? null : Map<String, dynamic>.from(row);
          }),
      _list =
          (({
            required String table,
            required String userId,
            required String orderColumn,
            required bool ascending,
          }) async {
            final rows = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .order(orderColumn, ascending: ascending);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          });

  @visibleForTesting
  SupabaseFavoriteRepository.testing({
    required String? Function() currentUserId,
    required FavoriteUpsertQuery upsert,
    required FavoriteDeleteQuery delete,
    required FavoriteContainsQuery contains,
    required FavoriteListQuery list,
  }) : _currentUserId = currentUserId,
       _upsert = upsert,
       _delete = delete,
       _contains = contains,
       _list = list;

  final String? Function() _currentUserId;
  final FavoriteUpsertQuery _upsert;
  final FavoriteDeleteQuery _delete;
  final FavoriteContainsQuery _contains;
  final FavoriteListQuery _list;

  @override
  Future<Result<Favorite>> add(String productId) async {
    try {
      final userId = _requireUserId();
      final row = await _upsert(
        table: 'favorites',
        values: {'user_id': userId, 'product_id': productId},
      );
      return Success(_mapFavorite(row));
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
  Future<Result<bool>> contains(String productId) async {
    try {
      final userId = _requireUserId();
      final row = await _contains(
        table: 'favorites',
        selectColumns: 'product_id',
        userId: userId,
        productId: productId,
      );
      return Success(row != null);
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
  Future<Result<List<Favorite>>> list() async {
    try {
      final userId = _requireUserId();
      final rows = await _list(
        table: 'favorites',
        userId: userId,
        orderColumn: 'created_at',
        ascending: false,
      );
      return Success(rows.map(_mapFavorite).toList(growable: false));
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
  Future<Result<void>> remove(String productId) async {
    try {
      final userId = _requireUserId();
      await _delete(table: 'favorites', userId: userId, productId: productId);
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

  Favorite _mapFavorite(SupabaseRow row) {
    final userId = requireString(row, 'user_id');
    final productId = requireString(row, 'product_id');
    return Favorite(
      id: '$userId:$productId',
      userId: userId,
      productId: productId,
      createdAt: optionalDateTime(row, 'created_at'),
    );
  }

  String _requireUserId() {
    final userId = _currentUserId();
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to manage favorites');
    }
    return userId;
  }
}
