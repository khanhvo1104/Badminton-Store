import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:base_project/features/orders/domain/entities/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _orderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _otherOrderId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _itemId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _otherItemId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _productId = '22222222-2222-4222-8222-222222222222';
const _variantId = '33333333-3333-4333-8333-333333333333';
const _placedAt = '2026-08-10T10:00:00.000Z';
const _updatedAt = '2026-08-10T12:00:00.000Z';
const _cancelledAt = '2026-08-10T14:00:00.000Z';
const _itemCreatedAt = '2026-08-10T10:01:00.000Z';

Never _unusedSeam() => throw StateError('database seam must not be invoked');

Map<String, dynamic> _orderRow({
  String id = _orderId,
  String orderNumber = 'BDM-20260810-000001',
  String userId = _userId,
  String status = 'confirmed',
  String paymentMethod = 'cod',
  String paymentStatus = 'paid',
  String currencyCode = 'VND',
  num subtotal = 500000,
  num discountTotal = 20000,
  num shippingFee = 30000,
  num grandTotal = 510000,
  String? customerNote = 'Leave at lobby',
  String recipientName = 'Nguyen Van A',
  String recipientPhone = '0901234567',
  Map<String, Object?>? shippingAddress,
  String? placedAt = _placedAt,
  String? cancelledAt,
  String? updatedAt = _updatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'order_number': orderNumber,
    'user_id': userId,
    'status': status,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'currency_code': currencyCode,
    'subtotal': subtotal,
    'discount_total': discountTotal,
    'shipping_fee': shippingFee,
    'grand_total': grandTotal,
    'customer_note': customerNote,
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    'shipping_address':
        shippingAddress ??
        const <String, Object?>{
          'province_name': 'Ho Chi Minh',
          'district_name': 'District 1',
          'ward_name': 'Ben Nghe',
          'street_address': '12 Nguyen Hue',
        },
    'placed_at': placedAt,
    'cancelled_at': cancelledAt,
    'updated_at': updatedAt,
  };
}

Map<String, dynamic> _itemRow({
  String id = _itemId,
  String orderId = _orderId,
  String? productId = _productId,
  String? variantId = _variantId,
  String productName = 'Yonex Astrox 99',
  String? variantName = '4U G5',
  String sku = 'YNX-AX99-4U',
  String? imagePath = 'products/yonex-astrox-99.jpg',
  num unitPrice = 250000,
  int quantity = 2,
  num lineTotal = 500000,
  Map<String, Object?>? productSnapshot,
  String? createdAt = _itemCreatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'order_id': orderId,
    'product_id': productId,
    'variant_id': variantId,
    'product_name': productName,
    'variant_name': variantName,
    'sku': sku,
    'image_path': imagePath,
    'unit_price': unitPrice,
    'quantity': quantity,
    'line_total': lineTotal,
    'product_snapshot':
        productSnapshot ??
        const <String, Object?>{'brand': 'Yonex', 'category': 'rackets'},
    'created_at': createdAt,
  };
}

SupabaseOrderRepository _repo({
  String? Function()? currentUserId,
  OrderListQuery? list,
  OrderGetByIdQuery? getById,
  OrderItemsListQuery? listItems,
}) {
  return SupabaseOrderRepository.testing(
    currentUserId: currentUserId ?? (() => _userId),
    list:
        list ??
        (({
          required String table,
          required String userId,
          required String orderColumn,
          required bool ascending,
          required int from,
          required int to,
        }) async => _unusedSeam()),
    getById:
        getById ??
        (({
          required String table,
          required String userId,
          required String orderId,
        }) async => _unusedSeam()),
    listItems:
        listItems ??
        (({
          required String table,
          required String orderId,
          required String orderColumn,
          required bool ascending,
        }) async => _unusedSeam()),
  );
}

void main() {
  group('unauthenticated boundary', () {
    test('list returns UnauthorizedException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
              required int from,
              required int to,
            }) async {
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list();

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<Order>>>());
      expect(
        (result as Failure<List<Order>>).error,
        isA<UnauthorizedException>(),
      );
      expect(result.error.message, 'Please sign in to view orders');
    });

    test('getById returns UnauthorizedException without DB seam', () async {
      var getCalls = 0;
      var itemCalls = 0;
      final repo = _repo(
        currentUserId: () => null,
        getById:
            ({
              required String table,
              required String userId,
              required String orderId,
            }) async {
              getCalls++;
              return _orderRow();
            },
        listItems:
            ({
              required String table,
              required String orderId,
              required String orderColumn,
              required bool ascending,
            }) async {
              itemCalls++;
              return const [];
            },
      );

      final result = await repo.getById(_orderId);

      expect(getCalls, 0);
      expect(itemCalls, 0);
      expect(result, isA<Failure<Order>>());
      expect((result as Failure<Order>).error, isA<UnauthorizedException>());
      expect(result.error.message, 'Please sign in to view orders');
    });
  });

  group('list pagination validation', () {
    test('page < 1 returns ValidationException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
              required int from,
              required int to,
            }) async {
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list(page: 0, pageSize: 20);

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<Order>>>());
      expect(
        (result as Failure<List<Order>>).error,
        isA<ValidationException>(),
      );
    });

    test('pageSize < 1 returns ValidationException without DB seam', () async {
      var seamCalls = 0;
      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
              required int from,
              required int to,
            }) async {
              seamCalls++;
              return const [];
            },
      );

      final result = await repo.list(page: 1, pageSize: 0);

      expect(seamCalls, 0);
      expect(result, isA<Failure<List<Order>>>());
      expect(
        (result as Failure<List<Order>>).error,
        isA<ValidationException>(),
      );
    });
  });

  group('list', () {
    test(
      'filters by auth user_id, orders by placed_at desc, uses inclusive range',
      () async {
        late String capturedTable;
        late String capturedUserId;
        late String capturedOrderColumn;
        late bool capturedAscending;
        late int capturedFrom;
        late int capturedTo;

        final repo = _repo(
          list:
              ({
                required String table,
                required String userId,
                required String orderColumn,
                required bool ascending,
                required int from,
                required int to,
              }) async {
                capturedTable = table;
                capturedUserId = userId;
                capturedOrderColumn = orderColumn;
                capturedAscending = ascending;
                capturedFrom = from;
                capturedTo = to;
                return [
                  _orderRow(),
                  _orderRow(
                    id: _otherOrderId,
                    orderNumber: 'BDM-20260810-000002',
                    status: 'pending',
                    paymentStatus: 'unpaid',
                    customerNote: null,
                    cancelledAt: null,
                    placedAt: null,
                    updatedAt: null,
                    discountTotal: 0,
                    shippingFee: 0,
                    grandTotal: 500000,
                  ),
                ];
              },
        );

        final result = await repo.list(page: 2, pageSize: 10);

        expect(capturedTable, 'orders');
        expect(capturedUserId, _userId);
        expect(capturedOrderColumn, 'placed_at');
        expect(capturedAscending, isFalse);
        expect(capturedFrom, 10);
        expect(capturedTo, 19);
        expect(result, isA<Success<List<Order>>>());
        final orders = (result as Success<List<Order>>).data;
        expect(orders, hasLength(2));

        expect(orders[0].id, _orderId);
        expect(orders[0].orderNumber, 'BDM-20260810-000001');
        expect(orders[0].userId, _userId);
        expect(orders[0].status, OrderStatus.confirmed);
        expect(orders[0].paymentMethod, 'cod');
        expect(orders[0].paymentStatus, PaymentStatus.paid);
        expect(orders[0].currencyCode, 'VND');
        expect(orders[0].subtotal, 500000);
        expect(orders[0].discountTotal, 20000);
        expect(orders[0].shippingFee, 30000);
        expect(orders[0].grandTotal, 510000);
        expect(orders[0].customerNote, 'Leave at lobby');
        expect(orders[0].recipientName, 'Nguyen Van A');
        expect(orders[0].recipientPhone, '0901234567');
        expect(orders[0].shippingAddress['street_address'], '12 Nguyen Hue');
        expect(orders[0].items, isEmpty);
        expect(orders[0].placedAt, DateTime.parse(_placedAt));
        expect(orders[0].cancelledAt, isNull);
        expect(orders[0].updatedAt, DateTime.parse(_updatedAt));

        expect(orders[1].id, _otherOrderId);
        expect(orders[1].status, OrderStatus.pending);
        expect(orders[1].paymentStatus, PaymentStatus.unpaid);
        expect(orders[1].customerNote, isNull);
        expect(orders[1].placedAt, isNull);
        expect(orders[1].updatedAt, isNull);
        expect(orders[1].discountTotal, 0);
        expect(orders[1].shippingFee, 0);
      },
    );

    test('page 1 pageSize 20 uses inclusive range 0..19', () async {
      late int capturedFrom;
      late int capturedTo;

      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
              required int from,
              required int to,
            }) async {
              capturedFrom = from;
              capturedTo = to;
              return const [];
            },
      );

      final result = await repo.list();

      expect(capturedFrom, 0);
      expect(capturedTo, 19);
      expect(result, isA<Success<List<Order>>>());
      expect((result as Success<List<Order>>).data, isEmpty);
    });

    test('unknown status and payment_status fall back safely', () async {
      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
              required int from,
              required int to,
            }) async {
              return [
                _orderRow(status: 'mystery', paymentStatus: 'mystery_pay'),
              ];
            },
      );

      final result = await repo.list();

      expect(result, isA<Success<List<Order>>>());
      final order = (result as Success<List<Order>>).data.single;
      expect(order.status, OrderStatus.pending);
      expect(order.paymentStatus, PaymentStatus.unpaid);
    });

    test('maps PostgrestException to DatabaseException with code', () async {
      final repo = _repo(
        list:
            ({
              required String table,
              required String userId,
              required String orderColumn,
              required bool ascending,
              required int from,
              required int to,
            }) async {
              throw const PostgrestException(
                message: 'list failed',
                code: '42501',
              );
            },
      );

      final result = await repo.list();

      expect(result, isA<Failure<List<Order>>>());
      final error = (result as Failure<List<Order>>).error;
      expect(error, isA<DatabaseException>());
      expect((error as DatabaseException).code, '42501');
      expect(error.message, 'list failed');
    });
  });

  group('getById', () {
    test(
      'filters by auth user_id and order id, then loads items by resolved id',
      () async {
        late String capturedOrderTable;
        late String capturedUserId;
        late String capturedOrderId;
        late String capturedItemsTable;
        late String capturedItemsOrderId;
        late String capturedItemsOrderColumn;
        late bool capturedItemsAscending;

        final repo = _repo(
          getById:
              ({
                required String table,
                required String userId,
                required String orderId,
              }) async {
                capturedOrderTable = table;
                capturedUserId = userId;
                capturedOrderId = orderId;
                return _orderRow(
                  cancelledAt: _cancelledAt,
                  status: 'cancelled',
                  paymentStatus: 'refunded',
                );
              },
          listItems:
              ({
                required String table,
                required String orderId,
                required String orderColumn,
                required bool ascending,
              }) async {
                capturedItemsTable = table;
                capturedItemsOrderId = orderId;
                capturedItemsOrderColumn = orderColumn;
                capturedItemsAscending = ascending;
                return [
                  _itemRow(),
                  _itemRow(
                    id: _otherItemId,
                    productId: null,
                    variantId: null,
                    variantName: null,
                    imagePath: null,
                    unitPrice: 100000,
                    quantity: 1,
                    lineTotal: 100000,
                    productSnapshot: const <String, Object?>{},
                  ),
                ];
              },
        );

        final result = await repo.getById(_orderId);

        expect(capturedOrderTable, 'orders');
        expect(capturedUserId, _userId);
        expect(capturedOrderId, _orderId);
        expect(capturedItemsTable, 'order_items');
        expect(capturedItemsOrderId, _orderId);
        expect(capturedItemsOrderColumn, 'created_at');
        expect(capturedItemsAscending, isTrue);
        expect(result, isA<Success<Order>>());

        final order = (result as Success<Order>).data;
        expect(order.id, _orderId);
        expect(order.orderNumber, 'BDM-20260810-000001');
        expect(order.userId, _userId);
        expect(order.status, OrderStatus.cancelled);
        expect(order.paymentMethod, 'cod');
        expect(order.paymentStatus, PaymentStatus.refunded);
        expect(order.currencyCode, 'VND');
        expect(order.subtotal, 500000);
        expect(order.discountTotal, 20000);
        expect(order.shippingFee, 30000);
        expect(order.grandTotal, 510000);
        expect(order.customerNote, 'Leave at lobby');
        expect(order.recipientName, 'Nguyen Van A');
        expect(order.recipientPhone, '0901234567');
        expect(order.shippingAddress['province_name'], 'Ho Chi Minh');
        expect(order.placedAt, DateTime.parse(_placedAt));
        expect(order.cancelledAt, DateTime.parse(_cancelledAt));
        expect(order.updatedAt, DateTime.parse(_updatedAt));
        expect(order.items, hasLength(2));

        final first = order.items[0];
        expect(first.id, _itemId);
        expect(first.orderId, _orderId);
        expect(first.productId, _productId);
        expect(first.variantId, _variantId);
        expect(first.productName, 'Yonex Astrox 99');
        expect(first.variantName, '4U G5');
        expect(first.sku, 'YNX-AX99-4U');
        expect(first.imagePath, 'products/yonex-astrox-99.jpg');
        expect(first.unitPrice, 250000);
        expect(first.quantity, 2);
        expect(first.lineTotal, 500000);
        expect(first.productSnapshot['brand'], 'Yonex');

        final second = order.items[1];
        expect(second.id, _otherItemId);
        expect(second.productId, isNull);
        expect(second.variantId, isNull);
        expect(second.variantName, isNull);
        expect(second.imagePath, isNull);
        expect(second.unitPrice, 100000);
        expect(second.quantity, 1);
        expect(second.lineTotal, 100000);
        expect(second.productSnapshot, isEmpty);
      },
    );

    test(
      'uses resolved order id for item lookup, not only request id',
      () async {
        const resolvedId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
        late String capturedItemsOrderId;

        final repo = _repo(
          getById:
              ({
                required String table,
                required String userId,
                required String orderId,
              }) async {
                return _orderRow(id: resolvedId);
              },
          listItems:
              ({
                required String table,
                required String orderId,
                required String orderColumn,
                required bool ascending,
              }) async {
                capturedItemsOrderId = orderId;
                return [_itemRow(orderId: resolvedId)];
              },
        );

        final result = await repo.getById(_orderId);

        expect(capturedItemsOrderId, resolvedId);
        expect(result, isA<Success<Order>>());
        final order = (result as Success<Order>).data;
        expect(order.id, resolvedId);
        expect(order.items.single.orderId, resolvedId);
      },
    );

    test('unknown status and payment_status fall back safely', () async {
      final repo = _repo(
        getById:
            ({
              required String table,
              required String userId,
              required String orderId,
            }) async {
              return _orderRow(status: 'weird', paymentStatus: 'also_weird');
            },
        listItems:
            ({
              required String table,
              required String orderId,
              required String orderColumn,
              required bool ascending,
            }) async {
              return const [];
            },
      );

      final result = await repo.getById(_orderId);

      expect(result, isA<Success<Order>>());
      final order = (result as Success<Order>).data;
      expect(order.status, OrderStatus.pending);
      expect(order.paymentStatus, PaymentStatus.unpaid);
      expect(order.items, isEmpty);
    });

    test(
      'maps PostgrestException from order lookup to DatabaseException with code',
      () async {
        var itemCalls = 0;
        final repo = _repo(
          getById:
              ({
                required String table,
                required String userId,
                required String orderId,
              }) async {
                throw const PostgrestException(
                  message: 'order missing',
                  code: 'PGRST116',
                );
              },
          listItems:
              ({
                required String table,
                required String orderId,
                required String orderColumn,
                required bool ascending,
              }) async {
                itemCalls++;
                return const [];
              },
        );

        final result = await repo.getById(_orderId);

        expect(itemCalls, 0);
        expect(result, isA<Failure<Order>>());
        final error = (result as Failure<Order>).error;
        expect(error, isA<DatabaseException>());
        expect((error as DatabaseException).code, 'PGRST116');
        expect(error.message, 'order missing');
      },
    );

    test(
      'maps PostgrestException from item lookup to DatabaseException with code',
      () async {
        final repo = _repo(
          getById:
              ({
                required String table,
                required String userId,
                required String orderId,
              }) async {
                return _orderRow();
              },
          listItems:
              ({
                required String table,
                required String orderId,
                required String orderColumn,
                required bool ascending,
              }) async {
                throw const PostgrestException(
                  message: 'items failed',
                  code: '42P01',
                );
              },
        );

        final result = await repo.getById(_orderId);

        expect(result, isA<Failure<Order>>());
        final error = (result as Failure<Order>).error;
        expect(error, isA<DatabaseException>());
        expect((error as DatabaseException).code, '42P01');
        expect(error.message, 'items failed');
      },
    );
  });
}
