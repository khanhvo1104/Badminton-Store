import 'package:meta/meta.dart';

/// Product media (`public.product_images`) — stores Storage path, not URL.
@immutable
class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.storagePath,
    this.variantId,
    this.altText,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  final String id;
  final String productId;
  final String? variantId;
  final String storagePath;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;

  ProductImage copyWith({
    String? id,
    String? productId,
    String? variantId,
    String? storagePath,
    String? altText,
    int? sortOrder,
    bool? isPrimary,
  }) {
    return ProductImage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      storagePath: storagePath ?? this.storagePath,
      altText: altText ?? this.altText,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductImage &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            productId == other.productId &&
            variantId == other.variantId &&
            storagePath == other.storagePath &&
            altText == other.altText &&
            sortOrder == other.sortOrder &&
            isPrimary == other.isPrimary;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    variantId,
    storagePath,
    altText,
    sortOrder,
    isPrimary,
  );
}
