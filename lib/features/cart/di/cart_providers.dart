import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/cart/data/repositories/supabase_cart_repository.dart';
import 'package:base_project/features/cart/domain/repositories/cart_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cart DI composition root.
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return SupabaseCartRepository(ref.watch(supabaseClientProvider));
});
