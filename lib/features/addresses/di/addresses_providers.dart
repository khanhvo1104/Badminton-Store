import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Addresses DI composition root.
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  throw UnimplementedError(
    'AddressRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
