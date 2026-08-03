import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/product/data/repositories/supabase_product_repository.dart';
import 'package:base_project/features/product/domain/repositories/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product DI composition root.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return SupabaseProductRepository(ref.watch(supabaseClientProvider));
});
