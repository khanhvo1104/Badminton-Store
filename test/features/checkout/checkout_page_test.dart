import 'dart:async';

import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_theme.dart';
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
import 'package:base_project/features/checkout/presentation/view_models/checkout_view_model.dart';
import 'package:base_project/features/checkout/presentation/views/checkout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

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
        quantity: 1,
        unitPriceSnapshot: 1500000,
        productName: 'Vợt Yonex',
        variantLabel: '3U',
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
    phoneNumber: '0900111222',
    provinceName: 'Ho Chi Minh',
    districtName: 'Quan 1',
    wardName: 'Ben Nghe',
    streetAddress: '12 Nguyen Hue',
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

  List<Override> overrides() => [
    cartRepositoryProvider.overrideWithValue(cartRepository),
    addressRepositoryProvider.overrideWithValue(addressRepository),
    checkoutRepositoryProvider.overrideWithValue(checkoutRepository),
  ];

  Future<void> pumpCheckout(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
    String initialLocation = AppRoutes.checkout,
  }) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.checkout,
          builder: (_, __) => const CheckoutPage(),
        ),
        GoRoute(
          path: AppRoutes.catalog,
          builder: (_, __) => const Scaffold(body: Text('catalog-page')),
        ),
        GoRoute(
          path: AppRoutes.orders,
          builder: (_, __) => const Scaffold(body: Text('orders-page')),
        ),
        GoRoute(
          path: AppRoutes.addresses,
          builder: (_, __) => const Scaffold(body: Text('addresses-page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides(), ...extraOverrides],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> ensureVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('shows loading then ready estimate labels and default address', (
    tester,
  ) async {
    final cartCompleter = Completer<Result<Cart>>();
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) => cartCompleter.future);
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([
        _address(id: 'addr-1', name: 'Other'),
        _address(id: 'addr-2', isDefault: true, name: 'Default User'),
      ]),
    );

    await pumpCheckout(tester);
    expect(find.byKey(const Key('checkout_loading')), findsOneWidget);

    cartCompleter.complete(Success(_cartWithItems()));
    await tester.pumpAndSettle();

    expect(find.text('Vợt Yonex'), findsOneWidget);
    expect(
      find.byKey(const Key('checkout_estimated_subtotal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout_estimate_disclaimer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('checkout_payment_method')), findsOneWidget);
    expect(find.byKey(const Key('checkout_shipping_fee')), findsOneWidget);
    expect(find.textContaining('Default User (mặc định)'), findsOneWidget);

    final radioGroup = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(radioGroup.groupValue, 'addr-2');
  });

  testWidgets('empty cart and empty address states expose safe actions', (
    tester,
  ) async {
    when(() => cartRepository.getCart()).thenAnswer(
      (_) async => const Success(
        Cart(id: 'cart-1', currencyCode: 'VND', status: 'active'),
      ),
    );

    await pumpCheckout(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout_empty_cart')), findsOneWidget);
    await tester.tap(find.text('Tiếp tục mua sắm'));
    await tester.pumpAndSettle();
    expect(find.text('catalog-page'), findsOneWidget);

    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(
      () => addressRepository.list(),
    ).thenAnswer((_) async => const Success([]));

    await pumpCheckout(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout_empty_addresses')), findsOneWidget);
    await tester.tap(find.text('Quản lý địa chỉ'));
    await tester.pumpAndSettle();
    expect(find.text('addresses-page'), findsOneWidget);
  });

  testWidgets('retryable load failure shows Vietnamese message', (
    tester,
  ) async {
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => const Failure(NetworkException('offline')));

    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout_load_failure')), findsOneWidget);
    expect(find.text(CheckoutUiMessages.loadFailed), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);

    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([_address(id: 'addr-1', isDefault: true)]),
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await ensureVisible(
      tester,
      find.byKey(const Key('checkout_submit_button')),
    );
    expect(find.byKey(const Key('checkout_submit_button')), findsOneWidget);
  });

  testWidgets('address switch, note entry, submit progress and success nav', (
    tester,
  ) async {
    when(
      () => cartRepository.getCart(),
    ).thenAnswer((_) async => Success(_cartWithItems()));
    when(() => addressRepository.list()).thenAnswer(
      (_) async => Success([
        _address(id: 'addr-1', isDefault: true, name: 'One'),
        _address(id: 'addr-2', name: 'Two'),
      ]),
    );

    final completer = Completer<Result<String>>();
    when(
      () => checkoutRepository.checkoutCod(
        shippingAddressId: any(named: 'shippingAddressId'),
        customerNote: any(named: 'customerNote'),
      ),
    ).thenAnswer((_) => completer.future);

    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    await ensureVisible(
      tester,
      find.byKey(const Key('checkout_address_addr-2')),
    );
    await tester.tap(find.byKey(const Key('checkout_address_addr-2')));
    await tester.pumpAndSettle();

    await ensureVisible(tester, find.byKey(const Key('checkout_note_field')));
    await tester.enterText(
      find.byKey(const Key('checkout_note_field')),
      'Giao buổi sáng',
    );
    await tester.pump();

    await ensureVisible(
      tester,
      find.byKey(const Key('checkout_submit_button')),
    );
    await tester.tap(find.byKey(const Key('checkout_submit_button')));
    await tester.pump();

    expect(find.byKey(const Key('checkout_submit_progress')), findsOneWidget);
    final submittingButton = tester.widget<FilledButton>(
      find.byKey(const Key('checkout_submit_button')),
    );
    expect(submittingButton.onPressed, isNull);

    completer.complete(const Success(_orderId));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout_success_order_id')), findsOneWidget);
    expect(find.textContaining(_orderId), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkout_view_orders')));
    await tester.pumpAndSettle();
    expect(find.text('orders-page'), findsOneWidget);
  });

  testWidgets(
    'insufficient stock failure stays editable with Vietnamese copy',
    (tester) async {
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

      await pumpCheckout(tester);
      await tester.pumpAndSettle();
      await ensureVisible(
        tester,
        find.byKey(const Key('checkout_submit_button')),
      );
      await tester.tap(find.byKey(const Key('checkout_submit_button')));
      await tester.pumpAndSettle();

      await ensureVisible(
        tester,
        find.byKey(const Key('checkout_submit_error')),
      );
      expect(find.byKey(const Key('checkout_submit_error')), findsOneWidget);
      expect(find.text(CheckoutUiMessages.insufficientStock), findsOneWidget);
      expect(find.textContaining('checkout_cod'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('checkout_submit_button')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('continue shopping from success navigates to catalog', (
    tester,
  ) async {
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
    ).thenAnswer((_) async => const Success(_orderId));

    await pumpCheckout(tester);
    await tester.pumpAndSettle();
    await ensureVisible(
      tester,
      find.byKey(const Key('checkout_submit_button')),
    );
    await tester.tap(find.byKey(const Key('checkout_submit_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout_continue_shopping')));
    await tester.pumpAndSettle();
    expect(find.text('catalog-page'), findsOneWidget);
  });
}
