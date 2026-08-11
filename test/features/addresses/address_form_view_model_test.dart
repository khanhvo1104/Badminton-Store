import 'dart:async';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:base_project/features/addresses/presentation/view_models/address_form_state.dart';
import 'package:base_project/features/addresses/presentation/view_models/address_form_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_container.dart';

class _MockAddressRepository extends Mock implements AddressRepository {}

Address _existing({
  String id = 'addr-1',
  String phone = '0901234567',
  bool isDefault = false,
}) {
  return Address(
    id: id,
    userId: 'user-1',
    recipientName: 'Nguyen Van A',
    phoneNumber: phone,
    provinceName: 'Ho Chi Minh',
    districtName: 'Quan 1',
    wardName: 'Ben Nghe',
    streetAddress: '12 Nguyen Hue',
    addressNote: 'Gate B',
    isDefault: isDefault,
  );
}

void main() {
  late _MockAddressRepository repository;

  setUpAll(() {
    registerFallbackValue(_existing());
  });

  setUp(() {
    repository = _MockAddressRepository();
  });

  Future<ProviderContainer> createContainer() {
    return createTestContainer(
      overrides: [addressRepositoryProvider.overrideWithValue(repository)],
    );
  }

  group('phone validation', () {
    test('accepts reasonable Vietnamese local and +84 formats', () {
      expect(AddressFormViewModel.validatePhone('0901234567'), isNull);
      expect(AddressFormViewModel.validatePhone('0901 234 567'), isNull);
      expect(AddressFormViewModel.validatePhone('+84901234567'), isNull);
      expect(AddressFormViewModel.validatePhone('84901234567'), isNull);
      expect(AddressFormViewModel.validatePhone('0351234567'), isNull);
    });

    test('rejects empty and clearly invalid numbers without repo calls', () {
      expect(
        AddressFormViewModel.validatePhone(''),
        AddressFormUiMessages.phoneRequired,
      );
      expect(
        AddressFormViewModel.validatePhone('123'),
        AddressFormUiMessages.phoneInvalid,
      );
      expect(
        AddressFormViewModel.validatePhone('0123456789'),
        AddressFormUiMessages.phoneInvalid,
      );
      expect(
        AddressFormViewModel.validatePhone('abcdefghij'),
        AddressFormUiMessages.phoneInvalid,
      );
      verifyNever(() => repository.create(any()));
      verifyNever(() => repository.update(any()));
    });
  });

  test('create validation blocks submit and never calls repository', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final provider = addressFormViewModelProvider(null);
    final sub = container.listen(provider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);

    await container.read(provider.notifier).submit();

    final state = container.read(provider);
    expect(state, isA<AddressFormEditing>());
    final form = state as AddressFormEditing;
    expect(form.recipientNameError, AddressFormUiMessages.recipientRequired);
    expect(form.phoneNumberError, AddressFormUiMessages.phoneRequired);
    expect(form.provinceNameError, AddressFormUiMessages.provinceRequired);
    expect(form.districtNameError, AddressFormUiMessages.districtRequired);
    expect(form.wardNameError, AddressFormUiMessages.wardRequired);
    expect(form.streetAddressError, AddressFormUiMessages.streetRequired);
    expect(form.isSubmitting, isFalse);
    verifyNever(() => repository.create(any()));
  });

  test(
    'create success calls create only, closes via success, invalidates list',
    () async {
      final created = _existing(id: 'new-1');
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => Success(created));
      when(() => repository.list()).thenAnswer((_) async => Success([created]));

      final container = await createContainer();
      addTearDown(container.dispose);

      final provider = addressFormViewModelProvider(null);
      final formSub = container.listen(
        provider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(formSub.close);
      final listSub = container.listen(
        addressesProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(listSub.close);

      final vm = container.read(provider.notifier)
        ..updateRecipientName(' Tran Van B ')
        ..updatePhoneNumber('0901-234-567')
        ..updateProvinceName(' Ha Noi ')
        ..updateDistrictName(' Ba Dinh ')
        ..updateWardName(' Cong Vi ')
        ..updateStreetAddress(' 10 Kim Ma ')
        ..updateAddressNote('  ')
        ..updateIsDefault(value: true);

      await vm.submit();

      expect(container.read(provider), isA<AddressFormSuccess>());
      final captured =
          verify(() => repository.create(captureAny())).captured.single
              as Address;
      expect(captured.id, isEmpty);
      expect(captured.userId, isEmpty);
      expect(captured.recipientName, 'Tran Van B');
      expect(captured.phoneNumber, '0901234567');
      expect(captured.provinceName, 'Ha Noi');
      expect(captured.districtName, 'Ba Dinh');
      expect(captured.wardName, 'Cong Vi');
      expect(captured.streetAddress, '10 Kim Ma');
      expect(captured.addressNote, isNull);
      expect(captured.isDefault, isTrue);
      verifyNever(() => repository.update(any()));

      // Invalidation triggers a list reload through the overridden repository.
      await container.read(addressesProvider.future);
      verify(() => repository.list()).called(greaterThanOrEqualTo(1));
    },
  );

  test(
    'create failure keeps form open with sanitized Vietnamese error',
    () async {
      when(() => repository.create(any())).thenAnswer(
        (_) async =>
            const Failure(DatabaseException('relation "addresses" boom')),
      );

      final container = await createContainer();
      addTearDown(container.dispose);

      final provider = addressFormViewModelProvider(null);
      final sub = container.listen(provider, (_, __) {}, fireImmediately: true);
      addTearDown(sub.close);

      final vm = container.read(provider.notifier)
        ..updateRecipientName('Tran Van B')
        ..updatePhoneNumber('0901234567')
        ..updateProvinceName('Ha Noi')
        ..updateDistrictName('Ba Dinh')
        ..updateWardName('Cong Vi')
        ..updateStreetAddress('10 Kim Ma');

      await vm.submit();

      final state = container.read(provider);
      expect(state, isA<AddressFormEditing>());
      final form = state as AddressFormEditing;
      expect(form.isSubmitting, isFalse);
      expect(form.generalError, AddressFormUiMessages.saveFailed);
      expect(form.generalError, isNot(contains('relation')));
    },
  );

  test(
    'edit prefills fields and submit calls update with preserved id',
    () async {
      final existing = _existing(id: 'addr-42', isDefault: true);
      when(() => repository.update(any())).thenAnswer(
        (_) async => Success(existing.copyWith(recipientName: 'Updated')),
      );

      final container = await createContainer();
      addTearDown(container.dispose);

      final provider = addressFormViewModelProvider(existing);
      final sub = container.listen(provider, (_, __) {}, fireImmediately: true);
      addTearDown(sub.close);

      final initial = container.read(provider) as AddressFormEditing;
      expect(initial.editingAddressId, 'addr-42');
      expect(initial.recipientName, 'Nguyen Van A');
      expect(initial.phoneNumber, '0901234567');
      expect(initial.provinceName, 'Ho Chi Minh');
      expect(initial.isDefault, isTrue);

      container.read(provider.notifier).updateRecipientName('Updated Name');
      await container.read(provider.notifier).submit();

      expect(container.read(provider), isA<AddressFormSuccess>());
      final captured =
          verify(() => repository.update(captureAny())).captured.single
              as Address;
      expect(captured.id, 'addr-42');
      expect(captured.userId, isEmpty);
      expect(captured.recipientName, 'Updated Name');
      verifyNever(() => repository.create(any()));
    },
  );

  test('duplicate submit is blocked while in flight', () async {
    final completer = Completer<Result<Address>>();
    when(() => repository.create(any())).thenAnswer((_) => completer.future);

    final container = await createContainer();
    addTearDown(container.dispose);

    final provider = addressFormViewModelProvider(null);
    final sub = container.listen(provider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);

    final vm = container.read(provider.notifier)
      ..updateRecipientName('Tran Van B')
      ..updatePhoneNumber('0901234567')
      ..updateProvinceName('Ha Noi')
      ..updateDistrictName('Ba Dinh')
      ..updateWardName('Cong Vi')
      ..updateStreetAddress('10 Kim Ma');

    final first = vm.submit();
    expect(
      (container.read(provider) as AddressFormEditing).isSubmitting,
      isTrue,
    );

    await vm.submit();
    verify(() => repository.create(any())).called(1);

    completer.complete(Success(_existing(id: 'new-1')));
    await first;
    expect(container.read(provider), isA<AddressFormSuccess>());
  });
}
