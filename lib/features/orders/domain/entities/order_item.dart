import 'package:meta/meta.dart';

@immutable
class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.productId,
    this.variantId,
    this.variantName,
    this.imagePath,
    this.productSnapshot = const {},
  });

  final String id;
  final String orderId;
  final String? productId;
  final String? variantId;
  final String productName;
  final String? variantName;
  final String sku;
  final String? imagePath;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final Map<String, Object?> productSnapshot;

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? variantId,
    String? productName,
    String? variantName,
    String? sku,
    String? imagePath,
    double? unitPrice,
    int? quantity,
    double? lineTotal,
    Map<String, Object?>? productSnapshot,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      variantName: variantName ?? this.variantName,
      sku: sku ?? this.sku,
      imagePath: imagePath ?? this.imagePath,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      lineTotal: lineTotal ?? this.lineTotal,
      productSnapshot: productSnapshot ?? this.productSnapshot,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OrderItem &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            orderId == other.orderId &&
            sku == other.sku &&
            quantity == other.quantity &&
            lineTotal == other.lineTotal;
  }

  @override
  int get hashCode => Object.hash(id, orderId, sku, quantity, lineTotal);
}
