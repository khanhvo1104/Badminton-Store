import 'package:base_project/shared/widgets/shop_placeholder_page.dart';
import 'package:flutter/material.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShopPlaceholderPage(
      title: 'Checkout',
      subtitle: 'Address, shipping, and payment will live here.',
      showBackButton: true,
    );
  }
}
