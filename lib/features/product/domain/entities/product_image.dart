import 'package:meta/meta.dart';

@immutable
class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    this.alt,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  final String id;
  final String url;
  final String? alt;
  final int sortOrder;
  final bool isPrimary;

  ProductImage copyWith({
    String? id,
    String? url,
    String? alt,
    int? sortOrder,
    bool? isPrimary,
  }) {
    return ProductImage(
      id: id ?? this.id,
      url: url ?? this.url,
      alt: alt ?? this.alt,
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
            url == other.url &&
            alt == other.alt &&
            sortOrder == other.sortOrder &&
            isPrimary == other.isPrimary;
  }

  @override
  int get hashCode => Object.hash(id, url, alt, sortOrder, isPrimary);
}
