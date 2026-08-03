import 'package:base_project/features/cart/domain/entities/cart_item.dart';
import 'package:meta/meta.dart';

@immutable
class Cart {
  const Cart({
    required this.id,
    required this.currencyCode,
    required this.status,
    this.userId,
    this.guestToken,
    this.items = const [],
    this.expiresAt,
    this.updatedAt,
  });

  final String id;
  final String? userId;
  final String? guestToken;

  /// `active` | `converted` | `abandoned` | `expired`
  final String status;
  final String currencyCode;
  final List<CartItem> items;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  bool get isEmpty => items.isEmpty;

  Cart copyWith({
    String? id,
    String? userId,
    String? guestToken,
    String? status,
    String? currencyCode,
    List<CartItem>? items,
    DateTime? expiresAt,
    DateTime? updatedAt,
  }) {
    return Cart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      guestToken: guestToken ?? this.guestToken,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      items: items ?? this.items,
      expiresAt: expiresAt ?? this.expiresAt,
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
            status == other.status &&
            currencyCode == other.currencyCode;
  }

  @override
  int get hashCode => Object.hash(id, userId, status, currencyCode);
}
