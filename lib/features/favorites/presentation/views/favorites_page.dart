import 'package:base_project/shared/widgets/shop_placeholder_page.dart';
import 'package:flutter/material.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShopPlaceholderPage(
      title: 'Favorites',
      subtitle: 'Saved products will appear here.',
    );
  }
}
