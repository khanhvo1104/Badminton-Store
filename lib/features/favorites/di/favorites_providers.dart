import 'package:base_project/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Favorites DI composition root.
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  throw UnimplementedError(
    'FavoriteRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
