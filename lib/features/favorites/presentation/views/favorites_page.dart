import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/favorites/di/favorites_providers.dart';
import 'package:base_project/features/product/di/product_providers.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final favoriteProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final favoritesResult = await ref.read(favoriteRepositoryProvider).list();
  final favorites = favoritesResult.when(
    success: (data) => data,
    failure: (error) => throw Exception(error.message),
  );

  final products = <Product>[];
  for (final favorite in favorites) {
    final productResult = await ref
        .read(productRepositoryProvider)
        .getById(favorite.productId);
    final product = productResult.when<Product?>(
      success: (data) => data,
      failure: (_) => null,
    );
    if (product != null) {
      products.add(product);
    }
  }
  return products;
});

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(favoriteProductsProvider);
          await ref.read(favoriteProductsProvider.future);
        },
        child: favoritesAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Bạn chưa lưu sản phẩm yêu thích nào')),
                ],
              );
            }
            return GridView.builder(
              padding: AppSpacing.page,
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                final variant = product.defaultVariant;
                return ProductCard(
                  title: product.name,
                  imageUrl: product.primaryImage?.storagePath,
                  priceAmount: (variant?.price ?? 0).round(),
                  compareAtAmount: variant?.compareAtPrice?.round(),
                  stockQuantity: variant?.availableQuantity,
                  isFavorite: true,
                  onTap: () =>
                      context.push(AppRoutes.productDetail(product.id)),
                  onFavoritePressed: (_) async {
                    await ref
                        .read(favoriteRepositoryProvider)
                        .remove(product.id);
                    ref.invalidate(favoriteProductsProvider);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Không tải được yêu thích: $error')),
        ),
      ),
    );
  }
}
