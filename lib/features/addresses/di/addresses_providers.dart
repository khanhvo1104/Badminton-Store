import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/addresses/data/repositories/supabase_address_repository.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:base_project/features/addresses/presentation/view_models/addresses_actions_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Addresses DI composition root.
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return SupabaseAddressRepository(ref.watch(supabaseClientProvider));
});

/// Owner address list for the Addresses screen.
///
/// Failures throw [Exception] with sanitized Vietnamese copy only — never
/// raw Supabase/database details from [AppException.message].
final addressesProvider = FutureProvider.autoDispose<List<Address>>((
  ref,
) async {
  final result = await ref.read(addressRepositoryProvider).list();
  return switch (result) {
    Success(data: final data) => data,
    Failure(error: final AppException error) => throw Exception(
      AddressesActionsFailureMapper.mapListFailure(error),
    ),
  };
});
