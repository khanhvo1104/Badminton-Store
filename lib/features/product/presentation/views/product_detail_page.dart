import 'package:base_project/shared/widgets/shop_placeholder_page.dart';
import 'package:flutter/material.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return ShopPlaceholderPage(
      title: 'Product',
      subtitle: 'Product detail for #$productId will appear here.',
      showBackButton: true,
    );
  }
}
