import 'package:meta/meta.dart';

@immutable
class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final bool isActive;

  Brand copyWith({
    String? id,
    String? name,
    String? slug,
    String? logoUrl,
    bool? isActive,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
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
            logoUrl == other.logoUrl &&
            isActive == other.isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, slug, logoUrl, isActive);
}
