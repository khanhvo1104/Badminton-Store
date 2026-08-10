import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/data/repositories/supabase_address_repository.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _otherUserId = '99999999-9999-4999-8999-999999999999';
const _addressId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _otherAddressId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _createdAt = '2026-08-10T10:00:00.000Z';
const _updatedAt = '2026-08-10T12:00:00.000Z';

Never _unusedSeam() => throw StateError('database seam must not be invoked');

Map<String, dynamic> _addressRow({
  String id = _addressId,
  String userId = _userId,
  String recipientName = 'Nguyen Van A',
  String phoneNumber = '0901234567',
  String? provinceCode = '79',
  String provinceName = 'Ho Chi Minh',
  String? districtCode = '760',
  String districtName = 'District 1',
  String? wardCode = '26734',
  String wardName = 'Ben Nghe',
  String streetAddress = '12 Nguyen Hue',
  String? addressNote = 'Gate B',
  bool isDefault = false,
  String? createdAt = _createdAt,
  String? updatedAt = _updatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'recipient_name': recipientName,
    'phone_number': phoneNumber,
    'province_code': provinceCode,
    'province_name': provinceName,
    'district_code': districtCode,
    'district_name': districtName,
    'ward_code': wardCode,
    'ward_name': wardName,
    'street_address': streetAddress,
    'address_note': addressNote,
    'is_default': isDefault,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Address _sampleAddress({
  String id = _addressId,
  String userId = _otherUserId,
  bool isDefault = false,
}) {
  return Address(
    id: id,
    userId: userId,
    recipientName: 'Nguyen Van A',
    phoneNumber: '0901234567',
    provinceCode: '79',
    provinceName: 'Ho Chi Minh',
    districtCode: '760',
    districtName: 'District 1',
    wardCode: '26734',
    wardName: 'Ben Nghe',
    streetAddress: '12 Nguyen Hue',
    addressNote: 'Gate B',
    isDefault: isDefault,
  );
}

const _editableKeys = {
  'recipient_name',
  'phone_number',
  'province_code',
  'province_name',
  'district_code',
  'district_name',
  'ward_code',
  'ward_name',
  'street_address',
  'address_note',
  'is_default',
};

SupabaseAddressRepository _repo({
  String? Function()? currentUserId,
  AddressListQuery? list,
  AddressGetByIdQuery? getById,
  AddressInsertQuery? insert,
  AddressUpdateQuery? update,
  AddressDeleteQuery? delete,
  AddressClearDefaultsQuery? clearDefaults,
  AddressSetDefaultFlagQuery? setDefaultFlag,
}) {
  return SupabaseAddressRepository.testing(
    currentUserId: currentUserId ?? (() => _userId),
    list:
        list ??
        (({
          required String table,
          required String userId,
          required String primaryOrderColumn,
          required bool primaryAscending,
          required String secondaryOrderColumn,
          required bool secondaryAscending,
        }) async => _unusedSeam()),
    getById:
        getById ??
        (({
          required String table,
          required String userId,
          required String addressId,
        }) async => _unusedSeam()),
    insert:
        insert ??
        (({
          required String table,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
    update:
        update ??
        (({
          required String table,
          required String userId,
          required String addressId,
          required Map<String, Object?> values,
        }) async => _unusedSeam()),
    delete:
        delete ??
        (({
          required String table,
          required String userId,
          required String addressId,
        }) async => _unusedSeam()),
    clearDefaults:
        clearDefaults ??
        (({
          required String table,
          required String userId,
          String? exceptId,
        }) async => _unusedSeam()),
    setDefaultFlag:
        setDefaultFlag ??
        (({
          required String table,
          required String userId,
          required String addressId,
        }) async => _unusedSeam()),
  );
}

void main() {
  group('unauthenticated boundary', () {
    test('list returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        list:
            ({
              required String table,
              required String userId,
              required String primaryOrderColumn,
              required bool primaryAscending,
              required String secondaryOrderColumn,
              required bool secondaryAscending,
            }) async {
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list();

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<Address>>>());
      expect(
        (result as Failure<List<Address>>).error,
        isA<UnauthorizedException>(),
      );
      expect(result.error.message, 'Please sign in to manage addresses');
    });

    test('getById returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        getById:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              seamCalls++;
              return _addressRow();
            },
      );

      final result = await repo.getById(_addressId);

      expect(seamCalls, 0);
      expect(result, isA<Failure<Address>>());
      expect((result as Failure<Address>).error, isA<UnauthorizedException>());
    });

    test('create returns UnauthorizedException without DB seam', () async {
      var insertCalls = 0;
      var clearCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        insert:
            ({
              required String table,
              required Map<String, Object?> values,
            }) async {
              insertCalls++;
              return _addressRow();
            },
        clearDefaults:
            ({
              required String table,
              required String userId,
              String? exceptId,
            }) async {
              clearCalls++;
            },
      );

      final result = await repo.create(_sampleAddress(isDefault: true));

      expect(insertCalls, 0);
      expect(clearCalls, 0);
      expect(result, isA<Failure<Address>>());
      expect((result as Failure<Address>).error, isA<UnauthorizedException>());
    });

    test('update returns UnauthorizedException without DB seam', () async {
      var updateCalls = 0;
      var clearCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        update:
            ({
              required String table,
              required String userId,
              required String addressId,
              required Map<String, Object?> values,
            }) async {
              updateCalls++;
              return _addressRow();
            },
        clearDefaults:
            ({
              required String table,
              required String userId,
              String? exceptId,
            }) async {
              clearCalls++;
            },
      );

      final result = await repo.update(_sampleAddress(isDefault: true));

      expect(updateCalls, 0);
      expect(clearCalls, 0);
      expect(result, isA<Failure<Address>>());
      expect((result as Failure<Address>).error, isA<UnauthorizedException>());
    });

    test('delete returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        delete:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              seamCalls++;
            },
      );

      final result = await repo.delete(_addressId);

      expect(seamCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<UnauthorizedException>());
    });

    test('setDefault returns UnauthorizedException without DB seam', () async {
      var clearCalls = 0;
      var setCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        clearDefaults:
            ({
              required String table,
              required String userId,
              String? exceptId,
            }) async {
              clearCalls++;
            },
        setDefaultFlag:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              setCalls++;
            },
      );

      final result = await repo.setDefault(_addressId);

      expect(clearCalls, 0);
      expect(setCalls, 0);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<UnauthorizedException>());
    });
  });

  group('list', () {
    test(
      'filters by auth user_id, orders defaults then updated_at, maps fields',
      () async {
        late String capturedTable;
        late String capturedUserId;
        late String capturedPrimaryOrder;
        late bool capturedPrimaryAscending;
        late String capturedSecondaryOrder;
        late bool capturedSecondaryAscending;

        final repo = _repo(
          list:
              ({
                required String table,
                required String userId,
                required String primaryOrderColumn,
                required bool primaryAscending,
                required String secondaryOrderColumn,
                required bool secondaryAscending,
              }) async {
                capturedTable = table;
                capturedUserId = userId;
                capturedPrimaryOrder = primaryOrderColumn;
                capturedPrimaryAscending = primaryAscending;
                capturedSecondaryOrder = secondaryOrderColumn;
                capturedSecondaryAscending = secondaryAscending;
                return [
                  _addressRow(isDefault: true),
                  _addressRow(
                    id: _otherAddressId,
                    provinceCode: null,
                    districtCode: null,
                    wardCode: null,
                    addressNote: null,
                    createdAt: null,
                    updatedAt: null,
                  ),
                ];
              },
        );

        final result = await repo.list();

        expect(capturedTable, 'addresses');
        expect(capturedUserId, _userId);
        expect(capturedPrimaryOrder, 'is_default');
        expect(capturedPrimaryAscending, isFalse);
        expect(capturedSecondaryOrder, 'updated_at');
        expect(capturedSecondaryAscending, isFalse);
        expect(result, isA<Success<List<Address>>>());
        final addresses = (result as Success<List<Address>>).data;
        expect(addresses, hasLength(2));

        expect(addresses[0].id, _addressId);
        expect(addresses[0].userId, _userId);
        expect(addresses[0].recipientName, 'Nguyen Van A');
        expect(addresses[0].phoneNumber, '0901234567');
        expect(addresses[0].provinceCode, '79');
        expect(addresses[0].provinceName, 'Ho Chi Minh');
        expect(addresses[0].districtCode, '760');
        expect(addresses[0].districtName, 'District 1');
        expect(addresses[0].wardCode, '26734');
        expect(addresses[0].wardName, 'Ben Nghe');
        expect(addresses[0].streetAddress, '12 Nguyen Hue');
        expect(addresses[0].addressNote, 'Gate B');
        expect(addresses[0].isDefault, isTrue);
        expect(addresses[0].createdAt, DateTime.parse(_createdAt));
        expect(addresses[0].updatedAt, DateTime.parse(_updatedAt));

        expect(addresses[1].provinceCode, isNull);
        expect(addresses[1].districtCode, isNull);
        expect(addresses[1].wardCode, isNull);
        expect(addresses[1].addressNote, isNull);
        expect(addresses[1].createdAt, isNull);
        expect(addresses[1].updatedAt, isNull);
        expect(addresses[1].isDefault, isFalse);
      },
    );

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String primaryOrderColumn,
              required bool primaryAscending,
              required String secondaryOrderColumn,
              required bool secondaryAscending,
            }) async {
              throw const PostgrestException(
                message: 'list failed',
                code: '42501',
              );
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<Address>>>());
      final error = (result as Failure<List<Address>>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42501');
      expect(error.message, 'list failed');
    });
  });

  group('getById', () {
    test('filters by authenticated user_id and address id', () async {
      late String capturedTable;
      late String capturedUserId;
      late String capturedAddressId;

      final repo = _repo(
        getById:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedAddressId = addressId;
              return _addressRow();
            },
      );

      final result = await repo.getById(_addressId);

      expect(capturedTable, 'addresses');
      expect(capturedUserId, _userId);
      expect(capturedAddressId, _addressId);
      expect(result, isA<Success<Address>>());
      expect((result as Success<Address>).data.id, _addressId);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        getById:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              throw const PostgrestException(
                message: 'not found',
                code: 'PGRST116',
              );
            },
      );

      final result = await repo.getById(_addressId);

      expect(result, isA<Failure<Address>>());
      expect(
        ((result as Failure<Address>).error as DatabaseException).code,
        'PGRST116',
      );
    });
  });

  group('create', () {
    test(
      'ignores caller ids and inserts auth owner plus editable fields only',
      () async {
        late String capturedTable;
        late Map<String, Object?> capturedValues;
        var clearCalls = 0;

        final repo = _repo(
          clearDefaults:
              ({
                required String table,
                required String userId,
                String? exceptId,
              }) async {
                clearCalls++;
              },
          insert:
              ({
                required String table,
                required Map<String, Object?> values,
              }) async {
                capturedTable = table;
                capturedValues = Map<String, Object?>.from(values);
                return _addressRow();
              },
        );

        final result = await repo.create(_sampleAddress(isDefault: false));

        expect(clearCalls, 0);
        expect(capturedTable, 'addresses');
        expect(capturedValues.keys.toSet(), {..._editableKeys, 'user_id'});
        expect(capturedValues.containsKey('id'), isFalse);
        expect(capturedValues['user_id'], _userId);
        expect(capturedValues['user_id'], isNot(_otherUserId));
        expect(capturedValues['recipient_name'], 'Nguyen Van A');
        expect(capturedValues['phone_number'], '0901234567');
        expect(capturedValues['province_code'], '79');
        expect(capturedValues['province_name'], 'Ho Chi Minh');
        expect(capturedValues['district_code'], '760');
        expect(capturedValues['district_name'], 'District 1');
        expect(capturedValues['ward_code'], '26734');
        expect(capturedValues['ward_name'], 'Ben Nghe');
        expect(capturedValues['street_address'], '12 Nguyen Hue');
        expect(capturedValues['address_note'], 'Gate B');
        expect(capturedValues['is_default'], isFalse);
        expect(result, isA<Success<Address>>());
      },
    );

    test(
      'default create clears only authenticated user defaults before insert',
      () async {
        late String clearTable;
        late String clearUserId;
        String? clearExceptId;
        var insertCalled = false;

        final repo = _repo(
          clearDefaults:
              ({
                required String table,
                required String userId,
                String? exceptId,
              }) async {
                clearTable = table;
                clearUserId = userId;
                clearExceptId = exceptId;
              },
          insert:
              ({
                required String table,
                required Map<String, Object?> values,
              }) async {
                insertCalled = true;
                expect(values['is_default'], isTrue);
                expect(values['user_id'], _userId);
                return _addressRow(isDefault: true);
              },
        );

        final result = await repo.create(_sampleAddress(isDefault: true));

        expect(clearTable, 'addresses');
        expect(clearUserId, _userId);
        expect(clearExceptId, isNull);
        expect(insertCalled, isTrue);
        expect(result, isA<Success<Address>>());
        expect((result as Success<Address>).data.isDefault, isTrue);
      },
    );

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        insert:
            ({
              required String table,
              required Map<String, Object?> values,
            }) async {
              throw const PostgrestException(
                message: 'insert failed',
                code: '23505',
              );
            },
      );

      final result = await repo.create(_sampleAddress());

      expect(result, isA<Failure<Address>>());
      expect(
        ((result as Failure<Address>).error as DatabaseException).code,
        '23505',
      );
    });
  });

  group('update', () {
    test('filters by owner and id; payload has editable fields only', () async {
      late String capturedTable;
      late String capturedUserId;
      late String capturedAddressId;
      late Map<String, Object?> capturedValues;
      var clearCalls = 0;

      final repo = _repo(
        clearDefaults:
            ({
              required String table,
              required String userId,
              String? exceptId,
            }) async {
              clearCalls++;
            },
        update:
            ({
              required String table,
              required String userId,
              required String addressId,
              required Map<String, Object?> values,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedAddressId = addressId;
              capturedValues = Map<String, Object?>.from(values);
              return _addressRow();
            },
      );

      final result = await repo.update(_sampleAddress(isDefault: false));

      expect(clearCalls, 0);
      expect(capturedTable, 'addresses');
      expect(capturedUserId, _userId);
      expect(capturedAddressId, _addressId);
      expect(capturedValues.keys.toSet(), _editableKeys);
      expect(capturedValues.containsKey('user_id'), isFalse);
      expect(capturedValues.containsKey('id'), isFalse);
      expect(capturedValues['recipient_name'], 'Nguyen Van A');
      expect(capturedValues['is_default'], isFalse);
      expect(result, isA<Success<Address>>());
    });

    test(
      'default update clears owner defaults excluding target then updates',
      () async {
        late String clearTable;
        late String clearUserId;
        late String? clearExceptId;

        final repo = _repo(
          clearDefaults:
              ({
                required String table,
                required String userId,
                String? exceptId,
              }) async {
                clearTable = table;
                clearUserId = userId;
                clearExceptId = exceptId;
              },
          update:
              ({
                required String table,
                required String userId,
                required String addressId,
                required Map<String, Object?> values,
              }) async {
                expect(userId, _userId);
                expect(addressId, _addressId);
                expect(values['is_default'], isTrue);
                return _addressRow(isDefault: true);
              },
        );

        final result = await repo.update(_sampleAddress(isDefault: true));

        expect(clearTable, 'addresses');
        expect(clearUserId, _userId);
        expect(clearExceptId, _addressId);
        expect(result, isA<Success<Address>>());
      },
    );

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        update:
            ({
              required String table,
              required String userId,
              required String addressId,
              required Map<String, Object?> values,
            }) async {
              throw const PostgrestException(
                message: 'update failed',
                code: '42P01',
              );
            },
      );

      final result = await repo.update(_sampleAddress());

      expect(result, isA<Failure<Address>>());
      expect(
        ((result as Failure<Address>).error as DatabaseException).code,
        '42P01',
      );
    });
  });

  group('delete', () {
    test('filters by authenticated user_id and address id', () async {
      late String capturedTable;
      late String capturedUserId;
      late String capturedAddressId;

      final repo = _repo(
        delete:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              capturedTable = table;
              capturedUserId = userId;
              capturedAddressId = addressId;
            },
      );

      final result = await repo.delete(_addressId);

      expect(capturedTable, 'addresses');
      expect(capturedUserId, _userId);
      expect(capturedAddressId, _addressId);
      expect(result, isA<Success<void>>());
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        delete:
            ({
              required String table,
              required String userId,
              required String addressId,
            }) async {
              throw const PostgrestException(
                message: 'delete failed',
                code: '42501',
              );
            },
      );

      final result = await repo.delete(_addressId);

      expect(result, isA<Failure<void>>());
      expect(
        ((result as Failure<void>).error as DatabaseException).code,
        '42501',
      );
    });
  });

  group('setDefault', () {
    test(
      'clears only owner defaults then updates only owner target address',
      () async {
        late String clearTable;
        late String clearUserId;
        String? clearExceptId;
        late String setTable;
        late String setUserId;
        late String setAddressId;
        var clearBeforeSet = false;
        var setCalled = false;

        final repo = _repo(
          clearDefaults:
              ({
                required String table,
                required String userId,
                String? exceptId,
              }) async {
                clearTable = table;
                clearUserId = userId;
                clearExceptId = exceptId;
                expect(setCalled, isFalse);
                clearBeforeSet = true;
              },
          setDefaultFlag:
              ({
                required String table,
                required String userId,
                required String addressId,
              }) async {
                setCalled = true;
                setTable = table;
                setUserId = userId;
                setAddressId = addressId;
              },
        );

        final result = await repo.setDefault(_addressId);

        expect(clearBeforeSet, isTrue);
        expect(clearTable, 'addresses');
        expect(clearUserId, _userId);
        expect(clearExceptId, isNull);
        expect(setTable, 'addresses');
        expect(setUserId, _userId);
        expect(setAddressId, _addressId);
        expect(result, isA<Success<void>>());
      },
    );

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        clearDefaults:
            ({
              required String table,
              required String userId,
              String? exceptId,
            }) async {
              throw const PostgrestException(
                message: 'clear failed',
                code: '23514',
              );
            },
      );

      final result = await repo.setDefault(_addressId);

      expect(result, isA<Failure<void>>());
      expect(
        ((result as Failure<void>).error as DatabaseException).code,
        '23514',
      );
    });
  });
}
