import 'package:meta/meta.dart';

/// Sellable SKU (`public.product_variants`).
///
/// [price] maps from `numeric(14,2)` VND (whole units in practice).
/// Stock comes from inventory / `get_variant_availability`, not this row.
@immutable
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.price,
    this.name,
    this.colorName,
    this.colorHex,
    this.racketWeightClass,
    this.gripSize,
    this.shoeSize,
    this.clothingSize,
    this.unit = 'item',
    this.compareAtPrice,
    this.attributes = const {},
    this.isDefault = false,
    this.isActive = true,
    this.availableQuantity,
    this.sortOrder = 0,
  });

  final String id;
  final String productId;
  final String sku;
  final String? name;
  final String? colorName;
  final String? colorHex;
  final String? racketWeightClass;
  final String? gripSize;
  final String? shoeSize;
  final String? clothingSize;
  final String unit;

  /// VND amount from `product_variants.price` (no float).
  final double price;
  final double? compareAtPrice;
  final Map<String, Object?> attributes;
  final bool isDefault;
  final bool isActive;
  final int sortOrder;

  /// Populated from public availability RPC/view — not stored on the variant.
  final int? availableQuantity;

  bool get isInStock => (availableQuantity ?? 0) > 0;

  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;

  ProductVariant copyWith({
    String? id,
    String? productId,
    String? sku,
    String? name,
    String? colorName,
    String? colorHex,
    String? racketWeightClass,
    String? gripSize,
    String? shoeSize,
    String? clothingSize,
    String? unit,
    double? price,
    double? compareAtPrice,
    Map<String, Object?>? attributes,
    bool? isDefault,
    bool? isActive,
    int? availableQuantity,
    int? sortOrder,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      colorName: colorName ?? this.colorName,
      colorHex: colorHex ?? this.colorHex,
      racketWeightClass: racketWeightClass ?? this.racketWeightClass,
      gripSize: gripSize ?? this.gripSize,
      shoeSize: shoeSize ?? this.shoeSize,
      clothingSize: clothingSize ?? this.clothingSize,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      attributes: attributes ?? this.attributes,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      sortOrder: sortOrder ?? this.sortOrder,
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
            price == other.price &&
            compareAtPrice == other.compareAtPrice &&
            isDefault == other.isDefault &&
            isActive == other.isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    sku,
    price,
    compareAtPrice,
    isDefault,
    isActive,
  );
}
