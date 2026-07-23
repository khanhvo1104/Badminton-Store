import 'package:base_project/shared/widgets/shop_placeholder_page.dart';
import 'package:flutter/material.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShopPlaceholderPage(
      title: 'Catalog',
      subtitle: 'Browse rackets, shoes, shuttlecocks, and more.',
    );
  }
}
