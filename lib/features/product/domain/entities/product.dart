import 'package:base_project/features/product/domain/entities/product_image.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';
import 'package:meta/meta.dart';

/// Catalog product (`public.products`). Price/stock live on variants/inventory.
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryId,
    required this.status,
    this.brandId,
    this.shortDescription,
    this.description,
    this.specifications = const {},
    this.searchKeywords,
    this.images = const [],
    this.variants = const [],
    this.isFeatured = false,
    this.publishedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String categoryId;
  final String? brandId;
  final String? shortDescription;
  final String? description;
  final Map<String, Object?> specifications;
  final String? searchKeywords;

  /// `draft` | `active` | `inactive` | `archived`
  final String status;
  final bool isFeatured;
  final DateTime? publishedAt;
  final List<ProductImage> images;
  final List<ProductVariant> variants;

  bool get isActive => status == 'active';

  ProductImage? get primaryImage {
    for (final image in images) {
      if (image.isPrimary && image.variantId == null) {
        return image;
      }
    }
    return images.isEmpty ? null : images.first;
  }

  ProductVariant? get defaultVariant {
    for (final variant in variants) {
      if (variant.isDefault) {
        return variant;
      }
    }
    return variants.isEmpty ? null : variants.first;
  }

  Product copyWith({
    String? id,
    String? name,
    String? slug,
    String? categoryId,
    String? brandId,
    String? shortDescription,
    String? description,
    Map<String, Object?>? specifications,
    String? searchKeywords,
    String? status,
    bool? isFeatured,
    DateTime? publishedAt,
    List<ProductImage>? images,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      specifications: specifications ?? this.specifications,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      publishedAt: publishedAt ?? this.publishedAt,
      images: images ?? this.images,
      variants: variants ?? this.variants,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Product &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            slug == other.slug &&
            categoryId == other.categoryId &&
            brandId == other.brandId &&
            shortDescription == other.shortDescription &&
            description == other.description &&
            status == other.status &&
            isFeatured == other.isFeatured &&
            publishedAt == other.publishedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    slug,
    categoryId,
    brandId,
    shortDescription,
    description,
    status,
    isFeatured,
    publishedAt,
  );
}
