import 'package:meta/meta.dart';

@immutable
class Favorite {
  const Favorite({
    required this.id,
    required this.userId,
    required this.productId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String productId;
  final DateTime? createdAt;

  Favorite copyWith({
    String? id,
    String? userId,
    String? productId,
    DateTime? createdAt,
  }) {
    return Favorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Favorite &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            productId == other.productId &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode => Object.hash(id, userId, productId, createdAt);
}
