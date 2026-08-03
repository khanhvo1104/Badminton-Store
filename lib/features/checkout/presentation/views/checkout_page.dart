import 'package:flutter/material.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Checkout vẫn đang bị khóa trong app vì schema hiện tại chỉ cho phép '
            'tạo order qua trusted RPC/backend flow. Chưa thể ghi trực tiếp vào '
            'orders từ client mà vẫn đảm bảo an toàn giá, tồn kho và lịch sử trạng thái.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
