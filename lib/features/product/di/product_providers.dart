import 'package:base_project/features/product/domain/repositories/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product DI composition root.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  throw UnimplementedError(
    'ProductRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
