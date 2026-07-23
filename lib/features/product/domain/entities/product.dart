import 'package:base_project/features/product/domain/entities/product_image.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';
import 'package:meta/meta.dart';

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryId,
    required this.brandId,
    this.description,
    this.images = const [],
    this.variants = const [],
    this.tags = const [],
    this.isActive = true,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String slug;
  final String categoryId;
  final String brandId;
  final String? description;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final List<String> tags;
  final bool isActive;
  final bool isFeatured;

  ProductImage? get primaryImage {
    for (final image in images) {
      if (image.isPrimary) {
        return image;
      }
    }
    return images.isEmpty ? null : images.first;
  }

  ProductVariant? get defaultVariant =>
      variants.isEmpty ? null : variants.first;

  Product copyWith({
    String? id,
    String? name,
    String? slug,
    String? categoryId,
    String? brandId,
    String? description,
    List<ProductImage>? images,
    List<ProductVariant>? variants,
    List<String>? tags,
    bool? isActive,
    bool? isFeatured,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      description: description ?? this.description,
      images: images ?? this.images,
      variants: variants ?? this.variants,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
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
            description == other.description &&
            _listEquals(images, other.images) &&
            _listEquals(variants, other.variants) &&
            _listEquals(tags, other.tags) &&
            isActive == other.isActive &&
            isFeatured == other.isFeatured;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    slug,
    categoryId,
    brandId,
    description,
    Object.hashAll(images),
    Object.hashAll(variants),
    Object.hashAll(tags),
    isActive,
    isFeatured,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
