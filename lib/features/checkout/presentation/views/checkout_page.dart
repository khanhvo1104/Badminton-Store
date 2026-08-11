import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/cart/domain/entities/cart_item.dart';
import 'package:base_project/features/checkout/presentation/view_models/checkout_state.dart';
import 'package:base_project/features/checkout/presentation/view_models/checkout_view_model.dart';
import 'package:base_project/shared/widgets/shop/price_label.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  late final TextEditingController _noteController;
  var _noteSeeded = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openAddressManagement() async {
    await context.push(AppRoutes.addresses);
    if (!mounted) {
      return;
    }
    _noteSeeded = false;
    await ref.read(checkoutViewModelProvider.notifier).load();
  }

  void _ensureNoteSeeded(CheckoutFormData data) {
    if (_noteSeeded) {
      return;
    }
    _noteSeeded = true;
    if (_noteController.text != data.customerNote) {
      _noteController.text = data.customerNote;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutViewModelProvider);
    final notifier = ref.read(checkoutViewModelProvider.notifier);

    final formData = switch (state) {
      CheckoutReady(:final data) ||
      CheckoutSubmitting(:final data) ||
      CheckoutSubmitFailure(:final data) => data,
      _ => null,
    };
    if (formData != null) {
      _ensureNoteSeeded(formData);
    } else {
      _noteSeeded = false;
    }

    return ShopPageScaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: switch (state) {
        CheckoutInitial() || CheckoutLoading() => const Center(
          child: CircularProgressIndicator(key: Key('checkout_loading')),
        ),
        CheckoutLoadFailure(:final message) => _MessageState(
          key: const Key('checkout_load_failure'),
          message: message,
          actionLabel: 'Thử lại',
          onAction: notifier.retry,
        ),
        CheckoutEmptyCart() => _MessageState(
          key: const Key('checkout_empty_cart'),
          message:
              'Giỏ hàng đang trống. Hãy thêm sản phẩm trước khi thanh toán.',
          actionLabel: 'Tiếp tục mua sắm',
          onAction: () => context.go(AppRoutes.catalog),
        ),
        CheckoutEmptyAddresses(:final cart) => _MessageState(
          key: const Key('checkout_empty_addresses'),
          message:
              'Bạn chưa có địa chỉ giao hàng. Vui lòng thêm địa chỉ để tiếp tục '
              '(giỏ hàng hiện có ${cart.itemCount} sản phẩm).',
          actionLabel: 'Quản lý địa chỉ',
          onAction: _openAddressManagement,
        ),
        CheckoutReady(:final data) => _CheckoutForm(
          data: data,
          noteController: _noteController,
          isSubmitting: false,
          errorMessage: null,
          onSelectAddress: notifier.selectAddress,
          onNoteChanged: notifier.updateNote,
          onSubmit: notifier.submit,
          onManageAddresses: _openAddressManagement,
        ),
        CheckoutSubmitting(:final data) => _CheckoutForm(
          data: data,
          noteController: _noteController,
          isSubmitting: true,
          errorMessage: null,
          onSelectAddress: null,
          onNoteChanged: null,
          onSubmit: null,
          onManageAddresses: null,
        ),
        CheckoutSubmitFailure(:final data, :final message) => _CheckoutForm(
          data: data,
          noteController: _noteController,
          isSubmitting: false,
          errorMessage: message,
          onSelectAddress: notifier.selectAddress,
          onNoteChanged: notifier.updateNote,
          onSubmit: notifier.submit,
          onManageAddresses: _openAddressManagement,
        ),
        CheckoutSuccess(:final orderId) => _SuccessState(orderId: orderId),
      },
    );
  }
}

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm({
    required this.data,
    required this.noteController,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSelectAddress,
    required this.onNoteChanged,
    required this.onSubmit,
    required this.onManageAddresses,
  });

  final CheckoutFormData data;
  final TextEditingController noteController;
  final bool isSubmitting;
  final String? errorMessage;
  final ValueChanged<String>? onSelectAddress;
  final ValueChanged<String>? onNoteChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onManageAddresses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: AppSpacing.page,
      children: [
        Text('Sản phẩm', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final item in data.cart.items) _CartLineTile(item: item),
        const SizedBox(height: AppSpacing.md),
        Text(
          key: const Key('checkout_estimated_subtotal'),
          'Tạm tính (ước tính): '
          '${PriceLabel.formatAmount(data.estimatedSubtotal.round(), data.cart.currencyCode)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          key: const Key('checkout_estimate_disclaimer'),
          'Số tiền trên chỉ mang tính tham khảo. Máy chủ sẽ kiểm tra lại giá, '
          'tổng tiền, trạng thái sản phẩm và tồn kho khi đặt hàng.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          key: const Key('checkout_payment_method'),
          'Thanh toán: COD (thu hộ khi nhận hàng)',
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          key: const Key('checkout_shipping_fee'),
          'Phí vận chuyển ước tính: 0₫',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'Địa chỉ giao hàng',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              key: const Key('checkout_manage_addresses'),
              onPressed: isSubmitting ? null : onManageAddresses,
              child: const Text('Quản lý'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        RadioGroup<String>(
          groupValue: data.selectedAddressId,
          onChanged: isSubmitting || onSelectAddress == null
              ? (_) {}
              : (value) {
                  if (value != null) {
                    onSelectAddress!(value);
                  }
                },
          child: Column(
            children: [
              for (final address in data.addresses)
                _AddressOption(address: address, enabled: !isSubmitting),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Ghi chú đơn hàng (tuỳ chọn)', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('checkout_note_field'),
          controller: noteController,
          enabled: !isSubmitting,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Ví dụ: giao giờ hành chính, gọi trước khi tới...',
          ),
          onChanged: onNoteChanged,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const Key('checkout_submit_error'),
            errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('checkout_submit_button'),
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(
                  key: Key('checkout_submit_progress'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Đặt hàng COD'),
        ),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.productName ?? 'Sản phẩm'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.variantLabel != null && item.variantLabel!.isNotEmpty)
            Text(item.variantLabel!),
          Text('SL: ${item.quantity}'),
        ],
      ),
      trailing: PriceLabel(
        amount: item.lineTotal.round(),
        currencyCode: 'VND',
        compact: true,
      ),
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({required this.address, required this.enabled});

  final Address address;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${address.streetAddress}, ${address.wardName}, '
        '${address.districtName}, ${address.provinceName}';

    return Card(
      key: Key('checkout_address_${address.id}'),
      child: RadioListTile<String>(
        value: address.id,
        enabled: enabled,
        title: Text(
          address.isDefault
              ? '${address.recipientName} (mặc định)'
              : address.recipientName,
        ),
        subtitle: Text('${address.phoneNumber}\n$formatted'),
        isThreeLine: true,
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text(
              key: const Key('checkout_success_title'),
              'Đặt hàng thành công',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              key: const Key('checkout_success_order_id'),
              'Mã đơn hàng: $orderId',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('checkout_view_orders'),
              onPressed: () => context.go(AppRoutes.orders),
              child: const Text('Xem đơn hàng'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('checkout_continue_shopping'),
              onPressed: () => context.go(AppRoutes.catalog),
              child: const Text('Tiếp tục mua sắm'),
            ),
          ],
        ),
      ),
    );
  }
}
