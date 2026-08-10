import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/addresses/data/repositories/supabase_address_repository.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Addresses DI composition root.
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return SupabaseAddressRepository(ref.watch(supabaseClientProvider));
});
