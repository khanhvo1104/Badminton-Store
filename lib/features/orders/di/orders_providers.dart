import 'package:base_project/features/orders/domain/repositories/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Orders DI composition root.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  throw UnimplementedError(
    'OrderRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
