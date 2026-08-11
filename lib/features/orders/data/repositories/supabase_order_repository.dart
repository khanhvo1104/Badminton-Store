import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/orders/domain/entities/order.dart';
import 'package:base_project/features/orders/domain/entities/order_item.dart';
import 'package:base_project/features/orders/domain/repositories/order_repository.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lists owner-scoped order rows with a single order column and inclusive range.
@visibleForTesting
typedef OrderListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String userId,
      required String orderColumn,
      required bool ascending,
      required int from,
      required int to,
    });

/// Fetches a single order scoped to owner + id.
@visibleForTesting
typedef OrderGetByIdQuery =
    Future<Map<String, dynamic>> Function({
      required String table,
      required String userId,
      required String orderId,
    });

/// Lists order-item rows for a resolved order with a single order column.
@visibleForTesting
typedef OrderItemsListQuery =
    Future<List<Map<String, dynamic>>> Function({
      required String table,
      required String orderId,
      required String orderColumn,
      required bool ascending,
    });

final class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(SupabaseClient client)
    : _currentUserId = (() => client.auth.currentUser?.id),
      _list =
          (({
            required String table,
            required String userId,
            required String orderColumn,
            required bool ascending,
            required int from,
            required int to,
          }) async {
            final rows = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .order(orderColumn, ascending: ascending)
                .range(from, to);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }),
      _getById =
          (({
            required String table,
            required String userId,
            required String orderId,
          }) async {
            final row = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .eq('id', orderId)
                .single();
            return Map<String, dynamic>.from(row);
          }),
      _listItems =
          (({
            required String table,
            required String orderId,
            required String orderColumn,
            required bool ascending,
          }) async {
            final rows = await client
                .from(table)
                .select()
                .eq('order_id', orderId)
                .order(orderColumn, ascending: ascending);
            return rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          });

  @visibleForTesting
  SupabaseOrderRepository.testing({
    required String? Function() currentUserId,
    required OrderListQuery list,
    required OrderGetByIdQuery getById,
    required OrderItemsListQuery listItems,
  }) : _currentUserId = currentUserId,
       _list = list,
       _getById = getById,
       _listItems = listItems;

  final String? Function() _currentUserId;
  final OrderListQuery _list;
  final OrderGetByIdQuery _getById;
  final OrderItemsListQuery _listItems;

  @override
  Future<Result<Order>> getById(String id) async {
    try {
      final userId = _requireUserId();
      final orderRow = await _getById(
        table: 'orders',
        userId: userId,
        orderId: id,
      );
      final resolvedOrderId = requireString(orderRow, 'id');
      final itemRows = await _listItems(
        table: 'order_items',
        orderId: resolvedOrderId,
        orderColumn: 'created_at',
        ascending: true,
      );
      return Success(
        _mapOrder(
          orderRow,
          items: itemRows.map(_mapItem).toList(growable: false),
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
    } on AppException catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<List<Order>>> list({int page = 1, int pageSize = 20}) async {
    try {
      final userId = _requireUserId();
      if (page < 1 || pageSize < 1) {
        throw const ValidationException(
          'page and pageSize must be greater than or equal to 1',
        );
      }
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await _list(
        table: 'orders',
        userId: userId,
        orderColumn: 'placed_at',
        ascending: false,
        from: from,
        to: to,
      );
      return Success(rows.map(_mapOrder).toList(growable: false));
    } on PostgrestException catch (error, stackTrace) {
      return Failure(
        DatabaseException(
          error.message,
          code: error.code,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on AppException catch (error) {
      return Failure(error);
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

  String _requireUserId() {
    final userId = _currentUserId();
    if (userId == null) {
      throw const UnauthorizedException('Please sign in to view orders');
    }
    return userId;
  }
}
