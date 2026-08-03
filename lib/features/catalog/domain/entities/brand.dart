import 'package:meta/meta.dart';

@immutable
class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.logoPath,
    this.websiteUrl,
    this.countryOfOrigin,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? logoPath;
  final String? websiteUrl;
  final String? countryOfOrigin;
  final int sortOrder;
  final bool isActive;

  Brand copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? logoPath,
    String? websiteUrl,
    String? countryOfOrigin,
    int? sortOrder,
    bool? isActive,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      logoPath: logoPath ?? this.logoPath,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Brand &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            slug == other.slug &&
            description == other.description &&
            logoPath == other.logoPath &&
            websiteUrl == other.websiteUrl &&
            countryOfOrigin == other.countryOfOrigin &&
            sortOrder == other.sortOrder &&
            isActive == other.isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    slug,
    description,
    logoPath,
    websiteUrl,
    countryOfOrigin,
    sortOrder,
    isActive,
  );
}
