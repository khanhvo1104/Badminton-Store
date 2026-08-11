import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';

/// Shopping cart persistence. Wired via SupabaseCartRepository.
abstract interface class CartRepository {
  Future<Result<Cart>> getCart();

  Future<Result<Cart>> addItem({
    required String productId,
    required String variantId,
    required int quantity,
  });

  Future<Result<Cart>> updateQuantity({
    required String itemId,
    required int quantity,
  });

  Future<Result<Cart>> removeItem(String itemId);

  Future<Result<void>> clear();
}
