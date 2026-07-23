import 'package:meta/meta.dart';

@immutable
class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.quantity,
    required this.unitPriceAmount,
    required this.currencyCode,
    this.productName,
    this.variantLabel,
    this.imageUrl,
  });

  final String id;
  final String productId;
  final String variantId;
  final int quantity;
  final int unitPriceAmount;
  final String currencyCode;
  final String? productName;
  final String? variantLabel;
  final String? imageUrl;

  int get lineTotalAmount => unitPriceAmount * quantity;

  CartItem copyWith({
    String? id,
    String? productId,
    String? variantId,
    int? quantity,
    int? unitPriceAmount,
    String? currencyCode,
    String? productName,
    String? variantLabel,
    String? imageUrl,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitPriceAmount: unitPriceAmount ?? this.unitPriceAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      productName: productName ?? this.productName,
      variantLabel: variantLabel ?? this.variantLabel,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CartItem &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            productId == other.productId &&
            variantId == other.variantId &&
            quantity == other.quantity &&
            unitPriceAmount == other.unitPriceAmount &&
            currencyCode == other.currencyCode &&
            productName == other.productName &&
            variantLabel == other.variantLabel &&
            imageUrl == other.imageUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    variantId,
    quantity,
    unitPriceAmount,
    currencyCode,
    productName,
    variantLabel,
    imageUrl,
  );
}
