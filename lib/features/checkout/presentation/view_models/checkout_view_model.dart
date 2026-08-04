import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/cart/di/cart_providers.dart';
import 'package:base_project/features/cart/presentation/views/cart_page.dart';
import 'package:base_project/features/checkout/data/repositories/supabase_checkout_repository.dart';
import 'package:base_project/features/checkout/di/checkout_providers.dart';
import 'package:base_project/features/checkout/presentation/view_models/checkout_state.dart';
import 'package:base_project/features/orders/presentation/views/orders_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Vietnamese copy for checkout failures — never raw backend/SQL text.
abstract final class CheckoutUiMessages {
  static const loadFailed =
      'Không tải được thông tin thanh toán. Vui lòng thử lại.';
  static const unauthenticated =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để đặt hàng.';
  static const inactiveProfile =
      'Tài khoản của bạn hiện không thể đặt hàng. Vui lòng liên hệ hỗ trợ.';
  static const invalidAddress =
      'Địa chỉ giao hàng không hợp lệ. Vui lòng chọn hoặc thêm địa chỉ của bạn.';
  static const invalidCart =
      'Giỏ hàng không sẵn sàng để thanh toán. Vui lòng kiểm tra lại giỏ hàng.';
  static const insufficientStock =
      'Một số sản phẩm không đủ tồn kho. Vui lòng giảm số lượng hoặc xem lại giỏ hàng.';
  static const unavailableCatalog =
      'Một số sản phẩm hiện không khả dụng. Vui lòng xem lại giỏ hàng.';
  static const generic = 'Không thể hoàn tất đơn hàng. Vui lòng thử lại sau.';
  static const missingSelection =
      'Vui lòng chọn địa chỉ giao hàng trước khi đặt hàng.';
}

class CheckoutViewModel extends StateNotifier<CheckoutState> {
  CheckoutViewModel(this._ref) : super(const CheckoutInitial()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const CheckoutLoading();

    final cartResult = await _ref.read(cartRepositoryProvider).getCart();
    if (!mounted) {
      return;
    }

    switch (cartResult) {
      case Failure(error: final error):
        state = CheckoutLoadFailure(_mapLoadFailure(error));
        return;
      case Success(data: final cart):
        if (cart.isEmpty) {
          state = const CheckoutEmptyCart();
          return;
        }

        final addressResult = await _ref.read(addressRepositoryProvider).list();
        if (!mounted) {
          return;
        }

        switch (addressResult) {
          case Failure(error: final error):
            state = CheckoutLoadFailure(_mapLoadFailure(error));
          case Success(data: final addresses):
            if (addresses.isEmpty) {
              state = CheckoutEmptyAddresses(cart: cart);
              return;
            }
            state = CheckoutReady(
              CheckoutFormData(
                cart: cart,
                addresses: addresses,
                selectedAddressId: _defaultAddressId(addresses),
              ),
            );
        }
    }
  }

  Future<void> retry() => load();

  void selectAddress(String addressId) {
    final current = state;
    final data = switch (current) {
      CheckoutReady(:final data) => data,
      CheckoutSubmitFailure(:final data) => data,
      _ => null,
    };
    if (data == null) {
      return;
    }
    final owned = data.addresses.any((address) => address.id == addressId);
    if (!owned) {
      return;
    }
    state = CheckoutReady(data.copyWith(selectedAddressId: addressId));
  }

  void updateNote(String note) {
    final current = state;
    final data = switch (current) {
      CheckoutReady(:final data) => data,
      CheckoutSubmitFailure(:final data) => data,
      _ => null,
    };
    if (data == null) {
      return;
    }
    state = CheckoutReady(data.copyWith(customerNote: note));
  }

  Future<void> submit() async {
    final current = state;
    final data = switch (current) {
      CheckoutReady(:final data) => data,
      CheckoutSubmitFailure(:final data) => data,
      _ => null,
    };
    if (data == null) {
      return;
    }

    final selected = data.selectedAddress;
    if (selected == null) {
      state = CheckoutSubmitFailure(
        data: data,
        message: CheckoutUiMessages.missingSelection,
      );
      return;
    }

    // Transition synchronously before the first await to block double taps.
    state = CheckoutSubmitting(data);

    final result = await _ref
        .read(checkoutRepositoryProvider)
        .checkoutCod(
          shippingAddressId: selected.id,
          customerNote: data.customerNote,
        );

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success(data: final orderId):
        _ref
          ..invalidate(cartProvider)
          ..invalidate(ordersProvider);
        state = CheckoutSuccess(orderId: orderId);
      case Failure(error: final error):
        state = CheckoutSubmitFailure(
          data: data,
          message: mapCheckoutFailure(error),
        );
    }
  }

  static String _defaultAddressId(List<Address> addresses) {
    for (final address in addresses) {
      if (address.isDefault) {
        return address.id;
      }
    }
    return addresses.first.id;
  }

  static String _mapLoadFailure(AppException error) {
    if (error is UnauthorizedException || error is AuthenticationException) {
      return CheckoutUiMessages.unauthenticated;
    }
    return CheckoutUiMessages.loadFailed;
  }

  /// Maps sanitized repository failures to Vietnamese UI copy.
  @visibleForTesting
  static String mapCheckoutFailure(AppException error) {
    final code = error.message;
    return switch (code) {
      CheckoutFailureCodes.unauthenticated =>
        CheckoutUiMessages.unauthenticated,
      CheckoutFailureCodes.inactiveProfile =>
        CheckoutUiMessages.inactiveProfile,
      CheckoutFailureCodes.invalidAddress => CheckoutUiMessages.invalidAddress,
      CheckoutFailureCodes.invalidCart => CheckoutUiMessages.invalidCart,
      CheckoutFailureCodes.insufficientStock =>
        CheckoutUiMessages.insufficientStock,
      CheckoutFailureCodes.unavailableCatalog =>
        CheckoutUiMessages.unavailableCatalog,
      CheckoutFailureCodes.invalidResponse => CheckoutUiMessages.generic,
      CheckoutFailureCodes.generic => CheckoutUiMessages.generic,
      _ => switch (error) {
        UnauthorizedException() ||
        AuthenticationException() => CheckoutUiMessages.unauthenticated,
        ValidationException() => CheckoutUiMessages.generic,
        _ => CheckoutUiMessages.generic,
      },
    };
  }
}

final checkoutViewModelProvider =
    StateNotifierProvider.autoDispose<CheckoutViewModel, CheckoutState>((ref) {
      return CheckoutViewModel(ref);
    });
