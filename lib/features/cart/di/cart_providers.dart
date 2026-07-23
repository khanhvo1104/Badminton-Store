import 'package:base_project/features/cart/domain/repositories/cart_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cart DI composition root.
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  throw UnimplementedError(
    'CartRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
