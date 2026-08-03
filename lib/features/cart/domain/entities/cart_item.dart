import 'package:meta/meta.dart';

@immutable
class CartItem {
  const CartItem({
    required this.id,
    required this.cartId,
    required this.variantId,
    required this.quantity,
    this.unitPriceSnapshot,
    this.productId,
    this.productName,
    this.variantLabel,
    this.imagePath,
  });

  final String id;
  final String cartId;
  final String variantId;
  final int quantity;

  /// Display-only snapshot; checkout re-fetches authoritative price.
  final double? unitPriceSnapshot;
  final String? productId;
  final String? productName;
  final String? variantLabel;
  final String? imagePath;

  double get lineTotal => (unitPriceSnapshot ?? 0) * quantity;

  CartItem copyWith({
    String? id,
    String? cartId,
    String? variantId,
    int? quantity,
    double? unitPriceSnapshot,
    String? productId,
    String? productName,
    String? variantLabel,
    String? imagePath,
  }) {
    return CartItem(
      id: id ?? this.id,
      cartId: cartId ?? this.cartId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitPriceSnapshot: unitPriceSnapshot ?? this.unitPriceSnapshot,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantLabel: variantLabel ?? this.variantLabel,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CartItem &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            cartId == other.cartId &&
            variantId == other.variantId &&
            quantity == other.quantity;
  }

  @override
  int get hashCode => Object.hash(id, cartId, variantId, quantity);
}
