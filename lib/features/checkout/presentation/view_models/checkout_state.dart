import 'dart:collection';

import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:meta/meta.dart';

/// Checkout screen state machine.
sealed class CheckoutState {
  const CheckoutState();
}

final class CheckoutInitial extends CheckoutState {
  const CheckoutInitial();
}

final class CheckoutLoading extends CheckoutState {
  const CheckoutLoading();
}

final class CheckoutLoadFailure extends CheckoutState {
  const CheckoutLoadFailure(this.message);

  final String message;
}

final class CheckoutEmptyCart extends CheckoutState {
  const CheckoutEmptyCart();
}

final class CheckoutEmptyAddresses extends CheckoutState {
  const CheckoutEmptyAddresses({required this.cart});

  final Cart cart;
}

@immutable
final class CheckoutFormData {
  CheckoutFormData({
    required this.cart,
    required List<Address> addresses,
    required this.selectedAddressId,
    this.customerNote = '',
  }) : addresses = UnmodifiableListView(addresses);

  final Cart cart;
  final UnmodifiableListView<Address> addresses;
  final String selectedAddressId;
  final String customerNote;

  Address? get selectedAddress {
    for (final address in addresses) {
      if (address.id == selectedAddressId) {
        return address;
      }
    }
    return null;
  }

  double get estimatedSubtotal => cart.subtotal;

  CheckoutFormData copyWith({
    Cart? cart,
    List<Address>? addresses,
    String? selectedAddressId,
    String? customerNote,
  }) {
    return CheckoutFormData(
      cart: cart ?? this.cart,
      addresses: addresses ?? this.addresses,
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      customerNote: customerNote ?? this.customerNote,
    );
  }
}

final class CheckoutReady extends CheckoutState {
  const CheckoutReady(this.data);

  final CheckoutFormData data;
}

final class CheckoutSubmitting extends CheckoutState {
  const CheckoutSubmitting(this.data);

  final CheckoutFormData data;
}

final class CheckoutSubmitFailure extends CheckoutState {
  const CheckoutSubmitFailure({required this.data, required this.message});

  final CheckoutFormData data;
  final String message;
}

final class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess({required this.orderId});

  final String orderId;
}
