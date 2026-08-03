import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/favorites/domain/entities/favorite.dart';
import 'package:base_project/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseFavoriteRepository implements FavoriteRepository {
  SupabaseFavoriteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Favorite>> add(String productId) async {
    final userId = _requireUserId();
    try {
      final row = await _client
          .from('favorites')
          .upsert({'user_id': userId, 'product_id': productId})
          .select()
          .single();
      return Success(_mapFavorite(Map<String, dynamic>.from(row)));
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
    final userId = _requireUserId();
    try {
      final row = await _client
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();
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
    final userId = _requireUserId();
    try {
      final rows = await _client
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return Success(
        rows
            .map((row) => _mapFavorite(Map<String, dynamic>.from(row)))
            .toList(growable: false),
      );
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
    final userId = _requireUserId();
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to manage favorites');
    }
    return userId;
  }
}
