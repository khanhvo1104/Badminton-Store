import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/favorites/data/repositories/supabase_favorite_repository.dart';
import 'package:base_project/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Favorites DI composition root.
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return SupabaseFavoriteRepository(ref.watch(supabaseClientProvider));
});
