import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Invokes `public.checkout_cod` with the trusted two-parameter payload.
@visibleForTesting
typedef CheckoutCodRpc =
    Future<dynamic> Function({
      required String functionName,
      required Map<String, Object?> params,
    });

/// Stable, sanitized application codes — never raw PostgREST/SQL text.
abstract final class CheckoutFailureCodes {
  static const unauthenticated = 'checkout_unauthenticated';
  static const inactiveProfile = 'checkout_inactive_profile';
  static const invalidAddress = 'checkout_invalid_address';
  static const invalidCart = 'checkout_invalid_cart';
  static const insufficientStock = 'checkout_insufficient_stock';
  static const unavailableCatalog = 'checkout_unavailable_catalog';
  static const invalidResponse = 'checkout_invalid_response';
  static const generic = 'checkout_generic_failure';
}

final class SupabaseCheckoutRepository implements CheckoutRepository {
  SupabaseCheckoutRepository({
    required CheckoutCodRpc rpc,
    required String? Function() currentUserId,
  }) : _rpc = rpc,
       _currentUserId = currentUserId;

  factory SupabaseCheckoutRepository.fromClient(SupabaseClient client) {
    return SupabaseCheckoutRepository(
      rpc:
          ({
            required String functionName,
            required Map<String, Object?> params,
          }) {
            return client.rpc(functionName, params: params);
          },
      currentUserId: () => client.auth.currentUser?.id,
    );
  }

  final CheckoutCodRpc _rpc;
  final String? Function() _currentUserId;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<Result<String>> checkoutCod({
    required String shippingAddressId,
    String? customerNote,
  }) async {
    if (_currentUserId() == null) {
      return const Failure(
        UnauthorizedException(CheckoutFailureCodes.unauthenticated),
      );
    }

    final params = <String, Object?>{
      'p_shipping_address_id': shippingAddressId,
      'p_customer_note': _normalizeNote(customerNote),
    };

    try {
      final raw = await _rpc(functionName: 'checkout_cod', params: params);
      final orderId = _parseOrderId(raw);
      if (orderId == null) {
        return const Failure(
          DatabaseException(CheckoutFailureCodes.invalidResponse),
        );
      }
      return Success(orderId);
    } on PostgrestException catch (error, stackTrace) {
      return Failure(_mapPostgrest(error, stackTrace));
    } on AuthException catch (error, stackTrace) {
      return Failure(
        UnauthorizedException(
          CheckoutFailureCodes.unauthenticated,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
    } on Object catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          CheckoutFailureCodes.generic,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  static String? _normalizeNote(String? note) {
    if (note == null) {
      return null;
    }
    final trimmed = note.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _parseOrderId(Object? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.toString().trim();
    if (value.isEmpty || !_uuidPattern.hasMatch(value)) {
      return null;
    }
    return value;
  }

  static AppException _mapPostgrest(
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    final signal = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();

    if (_containsAny(signal, const [
      'requires an authenticated user',
      'jwt',
      'not authenticated',
    ])) {
      return UnauthorizedException(
        CheckoutFailureCodes.unauthenticated,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_containsAny(signal, const ['requires an active profile'])) {
      return UnauthorizedException(
        CheckoutFailureCodes.inactiveProfile,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_containsAny(signal, const ['shipping address not found'])) {
      return ValidationException(
        CheckoutFailureCodes.invalidAddress,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_containsAny(signal, const [
      'requires an active cart',
      'cart is empty',
      'supports vnd carts only',
    ])) {
      return ValidationException(
        CheckoutFailureCodes.invalidCart,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_containsAny(signal, const ['insufficient stock'])) {
      return ValidationException(
        CheckoutFailureCodes.insufficientStock,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_containsAny(signal, const [
      'invalid catalog or inventory',
      'computed an invalid subtotal',
      'grand_total math failed',
    ])) {
      return ValidationException(
        CheckoutFailureCodes.unavailableCatalog,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return DatabaseException(
      CheckoutFailureCodes.generic,
      code: error.code,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}
