import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/checkout/data/repositories/supabase_checkout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _orderId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const _addressId = '11111111-2222-4333-8444-555555555555';

const _forbiddenParamKeys = <String>{
  'user_id',
  'p_user_id',
  'cart_id',
  'p_cart_id',
  'price',
  'p_price',
  'total',
  'p_total',
  'subtotal',
  'grand_total',
  'currency',
  'currency_code',
  'inventory',
  'payment',
  'payment_status',
  'payment_method',
  'status',
  'order_status',
  'role',
  'p_role',
};

void main() {
  test(
    'checkoutCod calls checkout_cod with exactly two trusted params',
    () async {
      late String capturedName;
      late Map<String, Object?> capturedParams;

      final repo = SupabaseCheckoutRepository(
        currentUserId: () => 'user-1',
        rpc:
            ({
              required String functionName,
              required Map<String, Object?> params,
            }) async {
              capturedName = functionName;
              capturedParams = Map<String, Object?>.from(params);
              return _orderId;
            },
      );

      final result = await repo.checkoutCod(
        shippingAddressId: _addressId,
        customerNote: '  please call  ',
      );

      expect(result, isA<Success<String>>());
      expect((result as Success<String>).data, _orderId);
      expect(capturedName, 'checkout_cod');
      expect(capturedParams.keys.toSet(), {
        'p_shipping_address_id',
        'p_customer_note',
      });
      expect(capturedParams['p_shipping_address_id'], _addressId);
      expect(capturedParams['p_customer_note'], 'please call');
      for (final key in _forbiddenParamKeys) {
        expect(capturedParams.containsKey(key), isFalse, reason: key);
      }
    },
  );

  test('blank and whitespace notes normalize to null', () async {
    late Map<String, Object?> capturedParams;

    final repo = SupabaseCheckoutRepository(
      currentUserId: () => 'user-1',
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async {
            capturedParams = Map<String, Object?>.from(params);
            return _orderId;
          },
    );

    await repo.checkoutCod(shippingAddressId: _addressId);
    expect(capturedParams['p_customer_note'], isNull);

    await repo.checkoutCod(shippingAddressId: _addressId, customerNote: '   ');
    expect(capturedParams['p_customer_note'], isNull);
  });

  test('unauthenticated caller never invokes RPC', () async {
    var rpcCalls = 0;
    final repo = SupabaseCheckoutRepository(
      currentUserId: () => null,
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async {
            rpcCalls++;
            return _orderId;
          },
    );

    final result = await repo.checkoutCod(shippingAddressId: _addressId);
    expect(rpcCalls, 0);
    expect(result, isA<Failure<String>>());
    final error = (result as Failure<String>).error;
    expect(error, isA<UnauthorizedException>());
    expect(error.message, CheckoutFailureCodes.unauthenticated);
  });

  test('invalid RPC return is sanitized', () async {
    final repo = SupabaseCheckoutRepository(
      currentUserId: () => 'user-1',
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async {
            return 'not-a-uuid';
          },
    );

    final result = await repo.checkoutCod(shippingAddressId: _addressId);
    expect(result, isA<Failure<String>>());
    final error = (result as Failure<String>).error;
    expect(error, isA<DatabaseException>());
    expect(error.message, CheckoutFailureCodes.invalidResponse);
    expect(error.message, isNot(contains('not-a-uuid')));
  });

  test('maps insufficient stock without leaking SQL', () async {
    final repo = SupabaseCheckoutRepository(
      currentUserId: () => 'user-1',
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) async {
            throw const PostgrestException(
              message: 'checkout_cod insufficient stock for variant abc',
              code: 'P0001',
            );
          },
    );

    final result = await repo.checkoutCod(shippingAddressId: _addressId);
    final error = (result as Failure<String>).error;
    expect(error, isA<ValidationException>());
    expect(error.message, CheckoutFailureCodes.insufficientStock);
    expect(error.message, isNot(contains('variant')));
    expect(error.message, isNot(contains('checkout_cod')));
  });

  test('maps address, cart, profile, and catalog failures', () async {
    Future<AppException> failureFor(String message) async {
      final repo = SupabaseCheckoutRepository(
        currentUserId: () => 'user-1',
        rpc:
            ({
              required String functionName,
              required Map<String, Object?> params,
            }) async {
              throw PostgrestException(message: message, code: 'P0001');
            },
      );
      final result = await repo.checkoutCod(shippingAddressId: _addressId);
      return (result as Failure<String>).error;
    }

    expect(
      (await failureFor('checkout_cod shipping address not found')).message,
      CheckoutFailureCodes.invalidAddress,
    );
    expect(
      (await failureFor('checkout_cod cart is empty')).message,
      CheckoutFailureCodes.invalidCart,
    );
    expect(
      (await failureFor('checkout_cod requires an active cart')).message,
      CheckoutFailureCodes.invalidCart,
    );
    expect(
      (await failureFor('checkout_cod requires an active profile')).message,
      CheckoutFailureCodes.inactiveProfile,
    );
    expect(
      (await failureFor(
        'checkout_cod cart contains invalid catalog or inventory rows',
      )).message,
      CheckoutFailureCodes.unavailableCatalog,
    );
    expect(
      (await failureFor('checkout_cod requires an authenticated user')).message,
      CheckoutFailureCodes.unauthenticated,
    );
  });

  test(
    'unrecognized Postgrest errors become sanitized generic failures',
    () async {
      const raw = 'relation "secret_table" does not exist';
      final repo = SupabaseCheckoutRepository(
        currentUserId: () => 'user-1',
        rpc:
            ({
              required String functionName,
              required Map<String, Object?> params,
            }) async {
              throw const PostgrestException(message: raw, code: '42P01');
            },
      );

      final result = await repo.checkoutCod(shippingAddressId: _addressId);
      final error = (result as Failure<String>).error;
      expect(error, isA<DatabaseException>());
      expect(error.message, CheckoutFailureCodes.generic);
      expect(error.message, isNot(contains('secret_table')));
      expect(error.toString(), isNot(contains('secret_table')));
    },
  );
}
