import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/catalog/data/repositories/supabase_brand_repository.dart';
import 'package:base_project/features/catalog/data/repositories/supabase_category_repository.dart';
import 'package:base_project/features/catalog/domain/repositories/brand_repository.dart';
import 'package:base_project/features/catalog/domain/repositories/category_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catalog DI composition root.
/// Repository implementations are registered in a later milestone.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SupabaseCategoryRepository(ref.watch(supabaseClientProvider));
});

final brandRepositoryProvider = Provider<BrandRepository>((ref) {
  return SupabaseBrandRepository(ref.watch(supabaseClientProvider));
});
