import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';

/// Shipping / billing addresses. Wired via SupabaseAddressRepository.
abstract interface class AddressRepository {
  Future<Result<List<Address>>> list();

  Future<Result<Address>> getById(String id);

  Future<Result<Address>> create(Address address);

  Future<Result<Address>> update(Address address);

  Future<Result<void>> delete(String id);

  Future<Result<void>> setDefault(String id);
}
