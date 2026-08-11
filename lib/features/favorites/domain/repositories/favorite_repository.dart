import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/favorites/domain/entities/favorite.dart';

/// Wishlist / favorites. Wired via SupabaseFavoriteRepository.
abstract interface class FavoriteRepository {
  Future<Result<List<Favorite>>> list();

  Future<Result<Favorite>> add(String productId);

  Future<Result<void>> remove(String productId);

  Future<Result<bool>> contains(String productId);
}
