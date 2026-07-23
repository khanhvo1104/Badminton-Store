import 'package:meta/meta.dart';

@immutable
class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.quantity,
    required this.unitPriceAmount,
    required this.currencyCode,
    this.variantLabel,
    this.imageUrl,
  });

  final String id;
  final String productId;
  final String variantId;
  final String productName;
  final String? variantLabel;
  final int quantity;
  final int unitPriceAmount;
  final String currencyCode;
  final String? imageUrl;

  int get lineTotalAmount => unitPriceAmount * quantity;

  OrderItem copyWith({
    String? id,
    String? productId,
    String? variantId,
    String? productName,
    String? variantLabel,
    int? quantity,
    int? unitPriceAmount,
    String? currencyCode,
    String? imageUrl,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      variantLabel: variantLabel ?? this.variantLabel,
      quantity: quantity ?? this.quantity,
      unitPriceAmount: unitPriceAmount ?? this.unitPriceAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OrderItem &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            productId == other.productId &&
            variantId == other.variantId &&
            productName == other.productName &&
            variantLabel == other.variantLabel &&
            quantity == other.quantity &&
            unitPriceAmount == other.unitPriceAmount &&
            currencyCode == other.currencyCode &&
            imageUrl == other.imageUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    variantId,
    productName,
    variantLabel,
    quantity,
    unitPriceAmount,
    currencyCode,
    imageUrl,
  );
}
