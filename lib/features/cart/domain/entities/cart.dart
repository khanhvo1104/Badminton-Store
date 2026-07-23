import 'package:base_project/features/cart/domain/entities/cart_item.dart';
import 'package:meta/meta.dart';

@immutable
class Cart {
  const Cart({
    required this.id,
    required this.currencyCode,
    this.userId,
    this.items = const [],
    this.updatedAt,
  });

  final String id;
  final String? userId;
  final String currencyCode;
  final List<CartItem> items;
  final DateTime? updatedAt;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotalAmount =>
      items.fold(0, (sum, item) => sum + item.lineTotalAmount);

  bool get isEmpty => items.isEmpty;

  Cart copyWith({
    String? id,
    String? userId,
    String? currencyCode,
    List<CartItem>? items,
    DateTime? updatedAt,
  }) {
    return Cart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currencyCode: currencyCode ?? this.currencyCode,
      items: items ?? this.items,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Cart &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            currencyCode == other.currencyCode &&
            _listEquals(items, other.items) &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, currencyCode, Object.hashAll(items), updatedAt);
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
