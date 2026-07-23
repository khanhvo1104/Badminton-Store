import 'package:base_project/features/catalog/domain/repositories/brand_repository.dart';
import 'package:base_project/features/catalog/domain/repositories/category_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catalog DI composition root.
/// Repository implementations are registered in a later milestone.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  throw UnimplementedError(
    'CategoryRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});

final brandRepositoryProvider = Provider<BrandRepository>((ref) {
  throw UnimplementedError(
    'BrandRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
