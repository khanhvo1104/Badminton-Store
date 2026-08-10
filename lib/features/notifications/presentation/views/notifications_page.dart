import 'package:base_project/shared/widgets/shop_placeholder_page.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShopPlaceholderPage(
      title: 'Notifications',
      subtitle: 'Order updates and promotions will appear here.',
      showBackButton: true,
    );
  }
}
