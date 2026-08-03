import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/product/domain/entities/product_image.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';

Product productFromCatalogRow(SupabaseRow row) {
  final imagePath = optionalString(row, 'primary_image_path');
  final minPrice = requireDouble(row, 'min_price');
  final minCompareAtPrice = row['min_compare_at_price'] == null
      ? null
      : requireDouble(row, 'min_compare_at_price');

  return Product(
    id: requireString(row, 'id'),
    name: requireString(row, 'name'),
    slug: requireString(row, 'slug'),
    categoryId: requireString(row, 'category_id'),
    brandId: optionalString(row, 'brand_id'),
    shortDescription: optionalString(row, 'short_description'),
    status: 'active',
    isFeatured: requireBool(row, 'is_featured'),
    publishedAt: optionalDateTime(row, 'published_at'),
    images: imagePath == null
        ? const []
        : [
            ProductImage(
              id: '${requireString(row, 'id')}:primary',
              productId: requireString(row, 'id'),
              storagePath: imagePath,
              isPrimary: true,
            ),
          ],
    variants: minPrice <= 0
        ? const []
        : [
            ProductVariant(
              id: '${requireString(row, 'id')}:summary',
              productId: requireString(row, 'id'),
              sku: 'SUMMARY-${requireString(row, 'id')}',
              price: minPrice,
              compareAtPrice: minCompareAtPrice,
              isDefault: true,
              availableQuantity: requireBool(row, 'has_stock') ? 1 : 0,
            ),
          ],
  );
}

Product productFromDetailRow(
  SupabaseRow row, {
  required List<ProductImage> images,
  required List<ProductVariant> variants,
}) {
  return Product(
    id: requireString(row, 'id'),
    name: requireString(row, 'name'),
    slug: requireString(row, 'slug'),
    categoryId: requireString(row, 'category_id'),
    brandId: optionalString(row, 'brand_id'),
    shortDescription: optionalString(row, 'short_description'),
    description: optionalString(row, 'description'),
    specifications: requireJsonMap(row, 'specifications'),
    searchKeywords: optionalString(row, 'search_keywords'),
    status: requireString(row, 'status'),
    isFeatured: requireBool(row, 'is_featured'),
    publishedAt: optionalDateTime(row, 'published_at'),
    images: images,
    variants: variants,
  );
}

ProductImage productImageFromRow(SupabaseRow row) {
  return ProductImage(
    id: requireString(row, 'id'),
    productId: requireString(row, 'product_id'),
    variantId: optionalString(row, 'variant_id'),
    storagePath: requireString(row, 'storage_path'),
    altText: optionalString(row, 'alt_text'),
    sortOrder: requireInt(row, 'sort_order'),
    isPrimary: requireBool(row, 'is_primary'),
  );
}

ProductVariant productVariantFromRow(
  SupabaseRow row, {
  int? availableQuantity,
}) {
  return ProductVariant(
    id: requireString(row, 'id'),
    productId: requireString(row, 'product_id'),
    sku: requireString(row, 'sku'),
    name: optionalString(row, 'name'),
    colorName: optionalString(row, 'color_name'),
    colorHex: optionalString(row, 'color_hex'),
    racketWeightClass: optionalString(row, 'racket_weight_class'),
    gripSize: optionalString(row, 'grip_size'),
    shoeSize: optionalString(row, 'shoe_size'),
    clothingSize: optionalString(row, 'clothing_size'),
    unit: optionalString(row, 'unit') ?? 'item',
    price: requireDouble(row, 'price'),
    compareAtPrice: row['compare_at_price'] == null
        ? null
        : requireDouble(row, 'compare_at_price'),
    attributes: requireJsonMap(row, 'attributes'),
    isDefault: requireBool(row, 'is_default'),
    isActive: requireBool(row, 'is_active', fallback: true),
    availableQuantity: availableQuantity,
    sortOrder: requireInt(row, 'sort_order'),
  );
}
