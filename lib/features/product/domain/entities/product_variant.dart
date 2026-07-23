import 'package:meta/meta.dart';

/// Sellable SKU under a product. Carries price and inventory hooks.
@immutable
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.priceAmount,
    required this.currencyCode,
    this.compareAtAmount,
    this.attributes = const {},
    this.stockQuantity = 0,
    this.isActive = true,
  });

  final String id;
  final String productId;
  final String sku;

  /// Price in minor units for [currencyCode] (e.g. VND whole units).
  final int priceAmount;
  final String currencyCode;
  final int? compareAtAmount;

  /// Variant options such as `{'size': '42', 'color': 'White'}`.
  final Map<String, String> attributes;
  final int stockQuantity;
  final bool isActive;

  bool get isInStock => stockQuantity > 0;

  bool get hasDiscount =>
      compareAtAmount != null && compareAtAmount! > priceAmount;

  ProductVariant copyWith({
    String? id,
    String? productId,
    String? sku,
    int? priceAmount,
    String? currencyCode,
    int? compareAtAmount,
    Map<String, String>? attributes,
    int? stockQuantity,
    bool? isActive,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      priceAmount: priceAmount ?? this.priceAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      compareAtAmount: compareAtAmount ?? this.compareAtAmount,
      attributes: attributes ?? this.attributes,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductVariant &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            productId == other.productId &&
            sku == other.sku &&
            priceAmount == other.priceAmount &&
            currencyCode == other.currencyCode &&
            compareAtAmount == other.compareAtAmount &&
            _mapEquals(attributes, other.attributes) &&
            stockQuantity == other.stockQuantity &&
            isActive == other.isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    sku,
    priceAmount,
    currencyCode,
    compareAtAmount,
    Object.hashAll(attributes.entries.map((e) => Object.hash(e.key, e.value))),
    stockQuantity,
    isActive,
  );
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
