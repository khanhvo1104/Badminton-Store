import 'package:meta/meta.dart';

@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? parentId,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      parentId: parentId ?? this.parentId,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Category &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            slug == other.slug &&
            parentId == other.parentId &&
            imageUrl == other.imageUrl &&
            sortOrder == other.sortOrder &&
            isActive == other.isActive;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, slug, parentId, imageUrl, sortOrder, isActive);
}
