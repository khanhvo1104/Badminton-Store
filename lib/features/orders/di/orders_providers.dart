import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:base_project/features/orders/domain/repositories/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Orders DI composition root.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return SupabaseOrderRepository(ref.watch(supabaseClientProvider));
});
