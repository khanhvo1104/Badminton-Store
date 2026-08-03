import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/cart/di/cart_providers.dart';
import 'package:base_project/features/favorites/di/favorites_providers.dart';
import 'package:base_project/features/product/di/product_providers.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';
import 'package:base_project/shared/widgets/shop/favorite_button.dart';
import 'package:base_project/shared/widgets/shop/price_label.dart';
import 'package:base_project/shared/widgets/shop/stock_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productDetailProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, productId) async {
      final result = await ref.read(productRepositoryProvider).getById(productId);
      return result.when(
        success: (data) => data,
        failure: (error) => throw Exception(error.message),
      );
    });

final favoriteStateProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, productId) async {
      final result = await ref.read(favoriteRepositoryProvider).contains(productId);
      return result.when(
        success: (data) => data,
        failure: (_) => false,
      );
    });

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  String? _selectedVariantId;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final favoriteAsync = ref.watch(favoriteStateProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          favoriteAsync.when(
            data: (isFavorite) => FavoriteButton(
              isFavorite: isFavorite,
              onPressed: () async {
                final repo = ref.read(favoriteRepositoryProvider);
                if (isFavorite) {
                  await repo.remove(widget.productId);
                } else {
                  await repo.add(widget.productId);
                }
                ref.invalidate(favoriteStateProvider(widget.productId));
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          final selectedVariant = _selectedVariant(product);
          return ListView(
            padding: AppSpacing.page,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.sports_tennis, size: 96),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (product.shortDescription != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(product.shortDescription!),
              ],
              const SizedBox(height: AppSpacing.md),
              PriceLabel(
                amount: selectedVariant.price.round(),
                compareAtAmount: selectedVariant.compareAtPrice?.round(),
              ),
              const SizedBox(height: AppSpacing.xs),
              StockIndicator(quantity: selectedVariant.availableQuantity ?? 0),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Biến thể',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variant in product.variants)
                    ChoiceChip(
                      label: Text(_variantLabel(variant)),
                      selected: selectedVariant.id == variant.id,
                      onSelected: (_) =>
                          setState(() => _selectedVariantId = variant.id),
                    ),
                ],
              ),
              if (product.description != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Mô tả',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(product.description!),
              ],
              if (product.specifications.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Thông số',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...product.specifications.entries.map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    trailing: Text('${entry.value}'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: selectedVariant.isActive
                    ? () async {
                        final result = await ref
                            .read(cartRepositoryProvider)
                            .addItem(
                              productId: product.id,
                              variantId: selectedVariant.id,
                              quantity: 1,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        final message = result.when(
                          success: (_) => 'Đã thêm vào giỏ hàng',
                          failure: (error) => error.message,
                        );
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Thêm vào giỏ'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Không tải được sản phẩm: $error')),
      ),
    );
  }

  ProductVariant _selectedVariant(Product product) {
    return product.variants.firstWhere(
      (variant) => variant.id == _selectedVariantId,
      orElse: () => product.defaultVariant ?? product.variants.first,
    );
  }

  String _variantLabel(ProductVariant variant) {
    final parts = <String>[
      if (variant.name != null && variant.name!.isNotEmpty) variant.name!,
      if (variant.colorName != null && variant.colorName!.isNotEmpty)
        variant.colorName!,
      if (variant.racketWeightClass != null &&
          variant.racketWeightClass!.isNotEmpty)
        variant.racketWeightClass!,
      if (variant.gripSize != null && variant.gripSize!.isNotEmpty)
        variant.gripSize!,
      if (variant.shoeSize != null && variant.shoeSize!.isNotEmpty)
        variant.shoeSize!,
      if (variant.clothingSize != null && variant.clothingSize!.isNotEmpty)
        variant.clothingSize!,
    ];
    return parts.isEmpty ? variant.sku : parts.join(' • ');
  }
}
