import 'package:base_project/features/orders/domain/entities/order_item.dart';
import 'package:meta/meta.dart';

enum OrderStatus {
  draft,
  pendingPayment,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded,
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.status,
    required this.currencyCode,
    required this.subtotalAmount,
    required this.totalAmount,
    this.items = const [],
    this.shippingAmount = 0,
    this.discountAmount = 0,
    this.shippingAddressId,
    this.paymentMethod,
    this.placedAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final OrderStatus status;
  final String currencyCode;
  final List<OrderItem> items;
  final int subtotalAmount;
  final int shippingAmount;
  final int discountAmount;
  final int totalAmount;
  final String? shippingAddressId;
  final String? paymentMethod;
  final DateTime? placedAt;
  final DateTime? updatedAt;

  Order copyWith({
    String? id,
    String? userId,
    OrderStatus? status,
    String? currencyCode,
    List<OrderItem>? items,
    int? subtotalAmount,
    int? shippingAmount,
    int? discountAmount,
    int? totalAmount,
    String? shippingAddressId,
    String? paymentMethod,
    DateTime? placedAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      items: items ?? this.items,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      shippingAmount: shippingAmount ?? this.shippingAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      shippingAddressId: shippingAddressId ?? this.shippingAddressId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      placedAt: placedAt ?? this.placedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Order &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            status == other.status &&
            currencyCode == other.currencyCode &&
            _listEquals(items, other.items) &&
            subtotalAmount == other.subtotalAmount &&
            shippingAmount == other.shippingAmount &&
            discountAmount == other.discountAmount &&
            totalAmount == other.totalAmount &&
            shippingAddressId == other.shippingAddressId &&
            paymentMethod == other.paymentMethod &&
            placedAt == other.placedAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    status,
    currencyCode,
    Object.hashAll(items),
    subtotalAmount,
    shippingAmount,
    discountAmount,
    totalAmount,
    shippingAddressId,
    paymentMethod,
    placedAt,
    updatedAt,
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
