import 'package:base_project/shared/widgets/shop_placeholder_page.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShopPlaceholderPage(
      title: 'Orders',
      subtitle: 'Order history and tracking will appear here.',
      showBackButton: true,
    );
  }
}
