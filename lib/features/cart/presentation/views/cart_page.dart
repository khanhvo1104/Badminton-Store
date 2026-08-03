import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/cart/di/cart_providers.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:base_project/shared/widgets/shop/price_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final cartProvider = FutureProvider.autoDispose<Cart>((ref) async {
  final result = await ref.read(cartRepositoryProvider).getCart();
  return result.when(
    success: (data) => data,
    failure: (error) => throw Exception(error.message),
  );
});

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Cart')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cartProvider);
          await ref.read(cartProvider.future);
        },
        child: cartAsync.when(
          data: (cart) {
            if (cart.items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Giỏ hàng đang trống')),
                ],
              );
            }
            return ListView(
              padding: AppSpacing.page,
              children: [
                ...cart.items.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.productName ?? 'Product'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.variantLabel != null &&
                              item.variantLabel!.isNotEmpty)
                            Text(item.variantLabel!),
                          Text('SL: ${item.quantity}'),
                          PriceLabel(
                            amount: (item.unitPriceSnapshot ?? 0).round(),
                            compact: true,
                          ),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(cartRepositoryProvider)
                                  .updateQuantity(
                                    itemId: item.id,
                                    quantity: item.quantity - 1,
                                  );
                              ref.invalidate(cartProvider);
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(cartRepositoryProvider)
                                  .updateQuantity(
                                    itemId: item.id,
                                    quantity: item.quantity + 1,
                                  );
                              ref.invalidate(cartProvider);
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(cartRepositoryProvider)
                                  .removeItem(item.id);
                              ref.invalidate(cartProvider);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Tạm tính: ${PriceLabel.formatAmount(cart.subtotal.round(), cart.currencyCode)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.push(AppRoutes.checkout),
                  child: const Text('Tiếp tục thanh toán'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Không tải được giỏ hàng: $error')),
        ),
      ),
    );
  }
}
