import 'dart:async';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:base_project/features/addresses/presentation/view_models/addresses_actions_state.dart';
import 'package:base_project/features/addresses/presentation/view_models/addresses_actions_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_container.dart';

class _MockAddressRepository extends Mock implements AddressRepository {}

Address _address({String id = 'addr-1', bool isDefault = false}) {
  return Address(
    id: id,
    userId: 'user-1',
    recipientName: 'Nguyen Van A',
    phoneNumber: '0901234567',
    provinceName: 'Ho Chi Minh',
    districtName: 'Quan 1',
    wardName: 'Ben Nghe',
    streetAddress: '12 Nguyen Hue',
    isDefault: isDefault,
  );
}

void main() {
  late _MockAddressRepository repository;

  setUp(() {
    repository = _MockAddressRepository();
  });

  test('delete success invalidates list and returns to idle', () async {
    when(
      () => repository.delete('addr-1'),
    ).thenAnswer((_) async => const Success(null));
    when(() => repository.list()).thenAnswer((_) async => const Success([]));

    final container = await createTestContainer(
      overrides: [addressRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final actionsSub = container.listen(
      addressesActionsViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(actionsSub.close);
    final listSub = container.listen(
      addressesProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(listSub.close);

    final ok = await container
        .read(addressesActionsViewModelProvider.notifier)
        .delete('addr-1');

    expect(ok, isTrue);
    expect(
      container.read(addressesActionsViewModelProvider),
      isA<AddressesActionsIdle>(),
    );
    verify(() => repository.delete('addr-1')).called(1);
    await container.read(addressesProvider.future);
    verify(() => repository.list()).called(greaterThanOrEqualTo(1));
  });

  test(
    'delete failure surfaces sanitized message and does not require list',
    () async {
      when(() => repository.delete('addr-1')).thenAnswer(
        (_) async => const Failure(DatabaseException('sql detail leak')),
      );

      final container = await createTestContainer(
        overrides: [addressRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        addressesActionsViewModelProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final ok = await container
          .read(addressesActionsViewModelProvider.notifier)
          .delete('addr-1');

      expect(ok, isFalse);
      final state = container.read(addressesActionsViewModelProvider);
      expect(state, isA<AddressesActionsFailure>());
      expect(
        (state as AddressesActionsFailure).message,
        AddressesActionsUiMessages.deleteFailed,
      );
      expect(state.message, isNot(contains('sql')));
      verifyNever(() => repository.list());
    },
  );

  test('setDefault success refreshes list after mutation', () async {
    when(
      () => repository.setDefault('addr-2'),
    ).thenAnswer((_) async => const Success(null));
    when(() => repository.list()).thenAnswer(
      (_) async => Success([_address(id: 'addr-2', isDefault: true)]),
    );

    final container = await createTestContainer(
      overrides: [addressRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final actionsSub = container.listen(
      addressesActionsViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(actionsSub.close);
    final listSub = container.listen(
      addressesProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(listSub.close);

    final ok = await container
        .read(addressesActionsViewModelProvider.notifier)
        .setDefault('addr-2');

    expect(ok, isTrue);
    verify(() => repository.setDefault('addr-2')).called(1);
    await container.read(addressesProvider.future);
    verify(() => repository.list()).called(greaterThanOrEqualTo(1));
  });

  test('duplicate delete/setDefault is blocked while busy', () async {
    final completer = Completer<Result<void>>();
    when(() => repository.delete('addr-1')).thenAnswer((_) => completer.future);

    final container = await createTestContainer(
      overrides: [addressRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      addressesActionsViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final vm = container.read(addressesActionsViewModelProvider.notifier);
    final first = vm.delete('addr-1');
    expect(
      container.read(addressesActionsViewModelProvider),
      isA<AddressesActionsBusy>(),
    );

    final secondDelete = await vm.delete('addr-2');
    final secondDefault = await vm.setDefault('addr-3');
    expect(secondDelete, isFalse);
    expect(secondDefault, isFalse);
    verify(() => repository.delete('addr-1')).called(1);
    verifyNever(() => repository.delete('addr-2'));
    verifyNever(() => repository.setDefault(any()));

    completer.complete(const Success(null));
    await first;
  });
}
