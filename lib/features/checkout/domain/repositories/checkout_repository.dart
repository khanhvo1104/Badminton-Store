import 'package:base_project/core/result/result.dart';

/// Trusted COD checkout. Identity, prices, totals, and stock are server-side.
abstract interface class CheckoutRepository {
  /// Places a COD order for the caller's active cart.
  ///
  /// Sends only [shippingAddressId] and an optional normalized [customerNote].
  /// Never accepts user ID, cart ID, prices, totals, currency, inventory,
  /// payment status, order status, or role from the client.
  Future<Result<String>> checkoutCod({
    required String shippingAddressId,
    String? customerNote,
  });
}
