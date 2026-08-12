import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/search/di/search_providers.dart';
import 'package:base_project/shared/widgets/shop/product_card.dart';
import 'package:base_project/shared/widgets/shop/product_card_grid.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final recentQueriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final result = await ref.read(searchRepositoryProvider).recentQueries();
  return result.when(success: (data) => data, failure: (_) => const <String>[]);
});

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<Product>, String>((ref, query) async {
      if (query.trim().isEmpty) {
        return const <Product>[];
      }
      final result = await ref
          .read(searchRepositoryProvider)
          .search(query: query);
      return result.when(
        success: (data) => data,
        failure: (error) => throw Exception(error.message),
      );
    });

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentAsync = ref.watch(recentQueriesProvider);
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return ShopPageScaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm, thương hiệu...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_query.isEmpty) ...[
            Text(
              'Tìm kiếm gần đây',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            recentAsync.when(
              data: (queries) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final query in queries)
                    ActionChip(
                      label: Text(query),
                      onPressed: () {
                        _controller.text = query;
                        setState(() => _query = query);
                      },
                    ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const Text('Không tải được lịch sử tìm kiếm'),
            ),
          ] else ...[
            resultsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Không tìm thấy sản phẩm')),
                  );
                }
                return ProductCardGridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final variant = product.defaultVariant;
                    return ProductCard(
                      title: product.name,
                      imageUrl: product.primaryImage?.storagePath,
                      priceAmount: (variant?.price ?? 0).round(),
                      compareAtAmount: variant?.compareAtPrice?.round(),
                      stockQuantity: variant?.availableQuantity,
                      onTap: () =>
                          context.push(AppRoutes.productDetail(product.id)),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Không thể tìm kiếm: $error')),
            ),
          ],
        ],
      ),
    );
  }
}
