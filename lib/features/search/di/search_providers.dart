import 'package:base_project/features/search/domain/repositories/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search DI composition root.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  throw UnimplementedError(
    'SearchRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
