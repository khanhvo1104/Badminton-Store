import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/orders/di/orders_providers.dart';
import 'package:base_project/features/orders/domain/entities/order.dart';
import 'package:base_project/shared/widgets/shop/price_label.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final result = await ref.read(orderRepositoryProvider).list(pageSize: 50);
  return result.when(
    success: (data) => data,
    failure: (error) => throw Exception(error.message),
  );
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return ShopPageScaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersProvider);
          await ref.read(ordersProvider.future);
        },
        child: ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Chưa có đơn hàng nào')),
                ],
              );
            }
            return ListView(
              padding: AppSpacing.page,
              children: [
                for (final order in orders)
                  Card(
                    child: ListTile(
                      title: Text(order.orderNumber),
                      subtitle: Text(
                        'Trạng thái: ${order.status.name}\nThanh toán: ${order.paymentStatus.name}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PriceLabel(
                            amount: order.grandTotal.round(),
                            currencyCode: order.currencyCode,
                            compact: true,
                          ),
                          if (order.placedAt != null)
                            Text(
                              '${order.placedAt!.day}/${order.placedAt!.month}/${order.placedAt!.year}',
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Không tải được đơn hàng: $error')),
        ),
      ),
    );
  }
}
