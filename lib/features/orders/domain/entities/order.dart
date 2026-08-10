import 'package:base_project/features/orders/domain/entities/order_item.dart';
import 'package:meta/meta.dart';

/// Order workflow status matching `public.orders.status`.
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  shipping,
  delivered,
  cancelled,
  returned,
}

enum PaymentStatus { unpaid, pending, paid, failed, refunded }

@immutable
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.currencyCode,
    required this.subtotal,
    required this.grandTotal,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    this.items = const [],
    this.discountTotal = 0,
    this.shippingFee = 0,
    this.customerNote,
    this.placedAt,
    this.cancelledAt,
    this.updatedAt,
  });

  final String id;
  final String orderNumber;
  final String userId;
  final OrderStatus status;
  final String paymentMethod;
  final PaymentStatus paymentStatus;
  final String currencyCode;
  final List<OrderItem> items;
  final double subtotal;
  final double discountTotal;
  final double shippingFee;
  final double grandTotal;
  final String? customerNote;
  final String recipientName;
  final String recipientPhone;

  /// Immutable address snapshot from `orders.shipping_address` jsonb.
  final Map<String, Object?> shippingAddress;
  final DateTime? placedAt;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;

  Order copyWith({
    String? id,
    String? orderNumber,
    String? userId,
    OrderStatus? status,
    String? paymentMethod,
    PaymentStatus? paymentStatus,
    String? currencyCode,
    List<OrderItem>? items,
    double? subtotal,
    double? discountTotal,
    double? shippingFee,
    double? grandTotal,
    String? customerNote,
    String? recipientName,
    String? recipientPhone,
    Map<String, Object?>? shippingAddress,
    DateTime? placedAt,
    DateTime? cancelledAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      currencyCode: currencyCode ?? this.currencyCode,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountTotal: discountTotal ?? this.discountTotal,
      shippingFee: shippingFee ?? this.shippingFee,
      grandTotal: grandTotal ?? this.grandTotal,
      customerNote: customerNote ?? this.customerNote,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      placedAt: placedAt ?? this.placedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Order &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            orderNumber == other.orderNumber &&
            userId == other.userId &&
            status == other.status &&
            paymentStatus == other.paymentStatus &&
            grandTotal == other.grandTotal;
  }

  @override
  int get hashCode =>
      Object.hash(id, orderNumber, userId, status, paymentStatus, grandTotal);
}
