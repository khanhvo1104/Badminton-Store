import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/orders/domain/entities/order.dart';
import 'package:base_project/features/orders/domain/entities/order_item.dart';
import 'package:base_project/features/orders/domain/repositories/order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Order>> getById(String id) async {
    try {
      final orderRow = await _client.from('orders').select().eq('id', id).single();
      final itemRows = await _client
          .from('order_items')
          .select()
          .eq('order_id', id)
          .order('created_at');
      return Success(
        _mapOrder(
          Map<String, dynamic>.from(orderRow),
          items: itemRows
              .map((row) => _mapItem(Map<String, dynamic>.from(row)))
              .toList(growable: false),
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<Order>>> list({int page = 1, int pageSize = 20}) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await _client
          .from('orders')
          .select()
          .order('placed_at', ascending: false)
          .range(from, to);
      return Success(
        rows
            .map((row) => _mapOrder(Map<String, dynamic>.from(row)))
            .toList(growable: false),
      );
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Order _mapOrder(SupabaseRow row, {List<OrderItem> items = const []}) {
    return Order(
      id: requireString(row, 'id'),
      orderNumber: requireString(row, 'order_number'),
      userId: requireString(row, 'user_id'),
      status: OrderStatus.values.firstWhere(
        (value) => value.name == requireString(row, 'status'),
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: requireString(row, 'payment_method'),
      paymentStatus: PaymentStatus.values.firstWhere(
        (value) => value.name == requireString(row, 'payment_status'),
        orElse: () => PaymentStatus.unpaid,
      ),
      currencyCode: requireString(row, 'currency_code'),
      subtotal: requireDouble(row, 'subtotal'),
      discountTotal: requireDouble(row, 'discount_total'),
      shippingFee: requireDouble(row, 'shipping_fee'),
      grandTotal: requireDouble(row, 'grand_total'),
      customerNote: optionalString(row, 'customer_note'),
      recipientName: requireString(row, 'recipient_name'),
      recipientPhone: requireString(row, 'recipient_phone'),
      shippingAddress: requireJsonMap(row, 'shipping_address'),
      items: items,
      placedAt: optionalDateTime(row, 'placed_at'),
      cancelledAt: optionalDateTime(row, 'cancelled_at'),
      updatedAt: optionalDateTime(row, 'updated_at'),
    );
  }

  OrderItem _mapItem(SupabaseRow row) {
    return OrderItem(
      id: requireString(row, 'id'),
      orderId: requireString(row, 'order_id'),
      productId: optionalString(row, 'product_id'),
      variantId: optionalString(row, 'variant_id'),
      productName: requireString(row, 'product_name'),
      variantName: optionalString(row, 'variant_name'),
      sku: requireString(row, 'sku'),
      imagePath: optionalString(row, 'image_path'),
      unitPrice: requireDouble(row, 'unit_price'),
      quantity: requireInt(row, 'quantity'),
      lineTotal: requireDouble(row, 'line_total'),
      productSnapshot: requireJsonMap(row, 'product_snapshot'),
    );
  }
}
