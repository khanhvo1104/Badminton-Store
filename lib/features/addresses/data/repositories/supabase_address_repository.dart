import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAddressRepository implements AddressRepository {
  SupabaseAddressRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Address>> create(Address address) async {
    try {
      if (address.isDefault) {
        await _clearDefault();
      }
      final row = await _client
          .from('addresses')
          .insert(_payload(address, includeId: false))
          .select()
          .single();
      return Success(_mapAddress(Map<String, dynamic>.from(row)));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _client.from('addresses').delete().eq('id', id);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Address>> getById(String id) async {
    try {
      final row = await _client
          .from('addresses')
          .select()
          .eq('id', id)
          .single();
      return Success(_mapAddress(Map<String, dynamic>.from(row)));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<Address>>> list() async {
    try {
      final rows = await _client
          .from('addresses')
          .select()
          .order('is_default', ascending: false)
          .order('updated_at', ascending: false);
      return Success(
        rows
            .map((row) => _mapAddress(Map<String, dynamic>.from(row)))
            .toList(growable: false),
      );
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setDefault(String id) async {
    try {
      await _clearDefault();
      await _client.from('addresses').update({'is_default': true}).eq('id', id);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Address>> update(Address address) async {
    try {
      if (address.isDefault) {
        await _clearDefault(exceptId: address.id);
      }
      final row = await _client
          .from('addresses')
          .update(_payload(address))
          .eq('id', address.id)
          .select()
          .single();
      return Success(_mapAddress(Map<String, dynamic>.from(row)));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _clearDefault({String? exceptId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to manage addresses');
    }
    var query = _client
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_default', true);
    if (exceptId != null) {
      query = query.neq('id', exceptId);
    }
    await query;
  }

  Address _mapAddress(SupabaseRow row) {
    return Address(
      id: requireString(row, 'id'),
      userId: requireString(row, 'user_id'),
      recipientName: requireString(row, 'recipient_name'),
      phoneNumber: requireString(row, 'phone_number'),
      provinceCode: optionalString(row, 'province_code'),
      provinceName: requireString(row, 'province_name'),
      districtCode: optionalString(row, 'district_code'),
      districtName: requireString(row, 'district_name'),
      wardCode: optionalString(row, 'ward_code'),
      wardName: requireString(row, 'ward_name'),
      streetAddress: requireString(row, 'street_address'),
      addressNote: optionalString(row, 'address_note'),
      isDefault: requireBool(row, 'is_default', fallback: false),
      createdAt: optionalDateTime(row, 'created_at'),
      updatedAt: optionalDateTime(row, 'updated_at'),
    );
  }

  Map<String, Object?> _payload(Address address, {bool includeId = true}) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to manage addresses');
    }
    final payload = <String, Object?>{
      'user_id': userId,
      'recipient_name': address.recipientName,
      'phone_number': address.phoneNumber,
      'province_code': address.provinceCode,
      'province_name': address.provinceName,
      'district_code': address.districtCode,
      'district_name': address.districtName,
      'ward_code': address.wardCode,
      'ward_name': address.wardName,
      'street_address': address.streetAddress,
      'address_note': address.addressNote,
      'is_default': address.isDefault,
    };
    if (includeId) {
      payload['id'] = address.id;
    }
    return payload;
  }
}
