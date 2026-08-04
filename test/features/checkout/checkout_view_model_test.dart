import 'dart:async';

import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:base_project/features/cart/di/cart_providers.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:base_project/features/cart/domain/entities/cart_item.dart';
import 'package:base_project/features/cart/domain/repositories/cart_repository.dart';
import 'package:base_project/features/checkout/data/repositories/supabase_checkout_repository.dart';
import 'package:base_project/features/checkout/di/checkout_providers.dart';
import 'package:base_project/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:base_project/features/checkout/presentation/view_models/checkout_state.dart';
import 'package:base_project/features/checkout/presentation/view_models/checkout_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_container.dart';

class _MockCartRepository extends Mock implements CartRepository {}

class _MockAddressRepository extends Mock implements AddressRepository {}

class _MockCheckoutRepository extends Mock implements CheckoutRepository {}

const _orderId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

Cart _cartWithItems() {
  return const Cart(
    id: 'cart-1',
    currencyCode: 'VND',
    status: 'active',
    items: [
      CartItem(
        id: 'item-1',
        cartId: 'cart-1',
        variantId: 'variant-1',
        quantity: 2,
        unitPriceSnapshot: 100000,
        productName: 'Vợt test',
        variantLabel: '4U',
      ),
    ],
  );
}

Address _address({
  required String id,
  bool isDefault = false,
  String name = 'Nguyen Van A',
}) {
  return Address(
    id: id,
    userId: 'user-1',
    recipientName: name,
    phoneNumber: '0900000000',
    provinceName: 'Ho Chi Minh',
    districtName: 'Quan 1',
    wardName: 'Ben Nghe',
    streetAddress: '123 Demo',
    isDefault: isDefault,
  );
}

void main() {
  late _MockCartRepository cartRepository;
  late _MockAddressRepository addressRepository;
  late _MockCheckoutRepository checkoutRepository;

  setUp(() {
    cartRepository = _MockCartRepository();
    addressRepository = _MockAddressRepository();
    checkoutRepository = _MockCheckoutRepository();
  });

  Future<ProviderContainer> createVmContainer() {
    return createTestContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(cartRepository),
        addressRepositoryProvider.overrideWithValue(addressRepository),
        checkoutRepositoryProvider.overrideWithValue(checkoutRepository),
      ],
    );
  }

  test('load selects default address then falls back to first', () async {
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([
        _address(id: 'addr-1'),
        _address(id: 'addr-2', isDefault: true, name: 'Default'),
      ]),
    );

    final container = await createVmContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      checkoutViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(checkoutViewModelProvider.notifier).load();
    final state = container.read(checkoutViewModelProvider);
    expect(state, isA<CheckoutReady>());
    expect((state as CheckoutReady).data.selectedAddressId, 'addr-2');

    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([
        _address(id: 'addr-1', name: 'First'),
        _address(id: 'addr-2', name: 'Second'),
      ]),
    );
    await container.read(checkoutViewModelProvider.notifier).load();
    final fallback = container.read(checkoutViewModelProvider) as CheckoutReady;
    expect(fallback.data.selectedAddressId, 'addr-1');
  });

  test('manual address switching works while ready', () async {
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([
        _address(id: 'addr-1', isDefault: true),
        _address(id: 'addr-2', name: 'Other'),
      ]),
    );

    final container = await createVmContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      checkoutViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(checkoutViewModelProvider.notifier).load();
    container.read(checkoutViewModelProvider.notifier).selectAddress('addr-2');
    final state = container.read(checkoutViewModelProvider) as CheckoutReady;
    expect(state.data.selectedAddressId, 'addr-2');

    container.read(checkoutViewModelProvider.notifier).selectAddress('missing');
    expect(
      (container.read(checkoutViewModelProvider) as CheckoutReady)
          .data
          .selectedAddressId,
      'addr-2',
    );
  });

  test('empty cart and empty addresses are explicit states', () async {
    when(() => cartRepository.getCart()).thenAnswer(
      (_) async => const Success(
        Cart(id: 'cart-1', currencyCode: 'VND', status: 'active'),
      ),
    );

    final container = await createVmContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      checkoutViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(checkoutViewModelProvider.notifier).load();
    expect(container.read(checkoutViewModelProvider), isA<CheckoutEmptyCart>());

    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(
      () => addressRepository.list(),
    ).thenAnswer((_) async => const Success([]));
    await container.read(checkoutViewModelProvider.notifier).load();
    expect(
      container.read(checkoutViewModelProvider),
      isA<CheckoutEmptyAddresses>(),
    );
  });

  test('cart load failure is retryable', () async {
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => const Failure(NetworkException('offline')));

    final container = await createVmContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      checkoutViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(checkoutViewModelProvider.notifier).load();
    final failed = container.read(checkoutViewModelProvider);
    expect(failed, isA<CheckoutLoadFailure>());
    expect(
      (failed as CheckoutLoadFailure).message,
      CheckoutUiMessages.loadFailed,
    );

    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([_address(id: 'addr-1', isDefault: true)]),
    );
    await container.read(checkoutViewModelProvider.notifier).retry();
    expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());
  });

  test(
    'submit succeeds once and blocks duplicate calls while pending',
    () async {
      when(
        () => cartRepository.getCart(),
      ).thenAnswer((_) async => Success(_cartWithItems()));
      when(() => addressRepository.list()).thenAnswer(
        (_) async => Success([_address(id: 'addr-1', isDefault: true)]),
      );

      final completer = Completer<Result<String>>();
      var calls = 0;
      when(
        () => checkoutRepository.checkoutCod(
          shippingAddressId: any(named: 'shippingAddressId'),
          customerNote: any(named: 'customerNote'),
        ),
      ).thenAnswer((_) {
        calls++;
        return completer.future;
      });

      final container = await createVmContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        checkoutViewModelProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(checkoutViewModelProvider.notifier).load();
      container.read(checkoutViewModelProvider.notifier).updateNote('  note  ');

      final first = container.read(checkoutViewModelProvider.notifier).submit();
      final second = container
          .read(checkoutViewModelProvider.notifier)
          .submit();
      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutSubmitting>(),
      );

      completer.complete(const Success(_orderId));
      await Future.wait([first, second]);

      expect(calls, 1);
      final success = container.read(checkoutViewModelProvider);
      expect(success, isA<CheckoutSuccess>());
      expect((success as CheckoutSuccess).orderId, _orderId);

      verify(
        () => checkoutRepository.checkoutCod(
          shippingAddressId: 'addr-1',
          customerNote: '  note  ',
        ),
      ).called(1);
    },
  );

  test('insufficient stock maps to actionable Vietnamese failure', () async {
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([_address(id: 'addr-1', isDefault: true)]),
    );
    when(
      () => checkoutRepository.checkoutCod(
        shippingAddressId: any(named: 'shippingAddressId'),
        customerNote: any(named: 'customerNote'),
      ),
    ).thenAnswer(
      (_) async => const Failure(
        ValidationException(CheckoutFailureCodes.insufficientStock),
      ),
    );

    final container = await createVmContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      checkoutViewModelProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(checkoutViewModelProvider.notifier).load();
    await container.read(checkoutViewModelProvider.notifier).submit();

    final state = container.read(checkoutViewModelProvider);
    expect(state, isA<CheckoutSubmitFailure>());
    expect(
      (state as CheckoutSubmitFailure).message,
      CheckoutUiMessages.insufficientStock,
    );
    expect(state.data.selectedAddressId, 'addr-1');
  });

  test('mapCheckoutFailure never surfaces raw backend text', () {
    expect(
      CheckoutViewModel.mapCheckoutFailure(
        const DatabaseException(CheckoutFailureCodes.generic),
      ),
      CheckoutUiMessages.generic,
    );
    expect(
      CheckoutViewModel.mapCheckoutFailure(
        const UnauthorizedException(CheckoutFailureCodes.unauthenticated),
      ),
      CheckoutUiMessages.unauthenticated,
    );
  });
}
