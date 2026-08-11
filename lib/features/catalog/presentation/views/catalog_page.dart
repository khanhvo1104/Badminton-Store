import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/catalog/di/catalog_providers.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';
import 'package:base_project/features/product/di/product_providers.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final catalogCategoriesProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) async {
  final result = await ref.read(categoryRepositoryProvider).list();
  return result.when(
    success: (data) => data.where((category) => category.isActive).toList(),
    failure: (error) => throw Exception(error.message),
  );
});

final catalogProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, String?>((ref, categoryId) async {
      final result = await ref
          .read(productRepositoryProvider)
          .list(categoryId: categoryId, pageSize: 60);
      return result.when(
        success: (data) => data,
        failure: (error) => throw Exception(error.message),
      );
    });

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final productsProvider = catalogProductsProvider(_selectedCategoryId);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Catalog'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.search),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(catalogCategoriesProvider)
            ..invalidate(productsProvider);
          await Future.wait([
            ref.read(catalogCategoriesProvider.future),
            ref.read(productsProvider.future),
          ]);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text(
              'Danh mục sản phẩm',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            categoriesAsync.when(
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) =>
                        setState(() => _selectedCategoryId = null),
                  ),
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category.name),
                      selected: _selectedCategoryId == category.id,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = category.id),
                    ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Không tải được danh mục: $error'),
            ),
            const SizedBox(height: AppSpacing.lg),
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Chưa có sản phẩm phù hợp')),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.58,
                  ),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final summaryVariant = product.defaultVariant;
                    return ProductCard(
                      title: product.name,
                      imageUrl: product.primaryImage?.storagePath,
                      priceAmount: (summaryVariant?.price ?? 0).round(),
                      compareAtAmount: summaryVariant?.compareAtPrice?.round(),
                      stockQuantity: summaryVariant?.availableQuantity,
                      onTap: () =>
                          context.push(AppRoutes.productDetail(product.id)),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(child: Text('Không tải được sản phẩm: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
