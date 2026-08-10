import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lists address rows for a user with primary then secondary ordering.
@visibleForTesting
typedef AddressListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String userId,
      required String primaryOrderColumn,
      required bool primaryAscending,
      required String secondaryOrderColumn,
      required bool secondaryAscending,
    });

/// Fetches a single address scoped to owner + id.
@visibleForTesting
typedef AddressGetByIdQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required String userId,
      required String addressId,
    });

/// Inserts an address row and returns the selected result.
@visibleForTesting
typedef AddressInsertQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required Map<String, Object?> values,
    });

/// Updates an address scoped to owner + id and returns the selected result.
@visibleForTesting
typedef AddressUpdateQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required String userId,
      required String addressId,
      required Map<String, Object?> values,
    });

/// Deletes an address scoped to owner + id.
@visibleForTesting
typedef AddressDeleteQuery =
    Future<void> Function({
      required String table,
      required String userId,
      required String addressId,
    });

/// Clears default flags for an owner's default rows, optionally excluding one id.
@visibleForTesting
typedef AddressClearDefaultsQuery =
    Future<void> Function({
      required String table,
      required String userId,
      String? exceptId,
    });

/// Marks a single owner-scoped address as default.
@visibleForTesting
typedef AddressSetDefaultFlagQuery =
    Future<void> Function({
      required String table,
      required String userId,
      required String addressId,
    });

final class SupabaseAddressRepository implements AddressRepository {
  SupabaseAddressRepository(SupabaseClient client)
    : _currentUserId = (() => client.auth.currentUser?.id),
      _list =
          (({
            required String table,
            required String userId,
            required String primaryOrderColumn,
            required bool primaryAscending,
            required String secondaryOrderColumn,
            required bool secondaryAscending,
          }) async {
            final rows = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .order(primaryOrderColumn, ascending: primaryAscending)
                .order(secondaryOrderColumn, ascending: secondaryAscending);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }),
      _getById =
          (({
            required String table,
            required String userId,
            required String addressId,
          }) async {
            final row = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .eq('id', addressId)
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _insert =
          (({
            required String table,
            required Map<String, Object?> values,
          }) async {
            final row = await client
                .from(table)
                .insert(values)
                .select()
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _update =
          (({
            required String table,
            required String userId,
            required String addressId,
            required Map<String, Object?> values,
          }) async {
            final row = await client
                .from(table)
                .update(values)
                .eq('user_id', userId)
                .eq('id', addressId)
                .select()
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _delete =
          (({
            required String table,
            required String userId,
            required String addressId,
          }) async {
            await client
                .from(table)
                .delete()
                .eq('user_id', userId)
                .eq('id', addressId);
          }),
      _clearDefaults =
          (({
            required String table,
            required String userId,
            String? exceptId,
          }) async {
            var query = client
                .from(table)
                .update({'is_default': false})
                .eq('user_id', userId)
                .eq('is_default', true);
            if (exceptId != null) {
              query = query.neq('id', exceptId);
            }
            await query;
          }),
      _setDefaultFlag =
          (({
            required String table,
            required String userId,
            required String addressId,
          }) async {
            await client
                .from(table)
                .update({'is_default': true})
                .eq('user_id', userId)
                .eq('id', addressId);
          });

  @visibleForTesting
  SupabaseAddressRepository.testing({
    required String? Function() currentUserId,
    required AddressListQuery list,
    required AddressGetByIdQuery getById,
    required AddressInsertQuery insert,
    required AddressUpdateQuery update,
    required AddressDeleteQuery delete,
    required AddressClearDefaultsQuery clearDefaults,
    required AddressSetDefaultFlagQuery setDefaultFlag,
  }) : _currentUserId = currentUserId,
       _list = list,
       _getById = getById,
       _insert = insert,
       _update = update,
       _delete = delete,
       _clearDefaults = clearDefaults,
       _setDefaultFlag = setDefaultFlag;

  final String? Function() _currentUserId;
  final AddressListQuery _list;
  final AddressGetByIdQuery _getById;
  final AddressInsertQuery _insert;
  final AddressUpdateQuery _update;
  final AddressDeleteQuery _delete;
  final AddressClearDefaultsQuery _clearDefaults;
  final AddressSetDefaultFlagQuery _setDefaultFlag;

  @override
  Future<Result<Address>> create(Address address) async {
    try {
      final userId = _requireUserId();
      if (address.isDefault) {
        await _clearDefaults(table: 'addresses', userId: userId);
      }
      final row = await _insert(
        table: 'addresses',
        values: _insertPayload(address, userId: userId),
      );
      return Success(_mapAddress(row));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final userId = _requireUserId();
      await _delete(table: 'addresses', userId: userId, addressId: id);
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
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<Address>> getById(String id) async {
    try {
      final userId = _requireUserId();
      final row = await _getById(
        table: 'addresses',
        userId: userId,
        addressId: id,
      );
      return Success(_mapAddress(row));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<List<Address>>> list() async {
    try {
      final userId = _requireUserId();
      final rows = await _list(
        table: 'addresses',
        userId: userId,
        primaryOrderColumn: 'is_default',
        primaryAscending: false,
        secondaryOrderColumn: 'updated_at',
        secondaryAscending: false,
      );
      return Success(rows.map(_mapAddress).toList(growable: false));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> setDefault(String id) async {
    try {
      final userId = _requireUserId();
      await _clearDefaults(table: 'addresses', userId: userId);
      await _setDefaultFlag(table: 'addresses', userId: userId, addressId: id);
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
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<Address>> update(Address address) async {
    try {
      final userId = _requireUserId();
      if (address.isDefault) {
        await _clearDefaults(
          table: 'addresses',
          userId: userId,
          exceptId: address.id,
        );
      }
      final row = await _update(
        table: 'addresses',
        userId: userId,
        addressId: address.id,
        values: _editablePayload(address),
      );
      return Success(_mapAddress(row));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    }
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

  Map<String, Object?> _insertPayload(
    Address address, {
    required String userId,
  }) {
    return <String, Object?>{'user_id': userId, ..._editablePayload(address)};
  }

  Map<String, Object?> _editablePayload(Address address) {
    return <String, Object?>{
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
  }

  String _requireUserId() {
    final userId = _currentUserId();
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to manage addresses');
    }
    return userId;
  }
}
