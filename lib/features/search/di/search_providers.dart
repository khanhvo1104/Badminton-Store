import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/search/data/repositories/supabase_search_repository.dart';
import 'package:base_project/features/search/domain/repositories/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search DI composition root.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SupabaseSearchRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(preferencesServiceProvider),
  );
});
