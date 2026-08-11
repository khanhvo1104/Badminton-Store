import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/presentation/view_models/address_form_state.dart';
import 'package:base_project/features/addresses/presentation/view_models/address_form_view_model.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Create / edit address form. Ownership is never collected here.
class AddressFormPage extends ConsumerStatefulWidget {
  const AddressFormPage({super.key, this.existing});

  final Address? existing;

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  late final TextEditingController _recipientController;
  late final TextEditingController _phoneController;
  late final TextEditingController _provinceController;
  late final TextEditingController _districtController;
  late final TextEditingController _wardController;
  late final TextEditingController _streetController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _recipientController = TextEditingController(
      text: existing?.recipientName ?? '',
    );
    _phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    _provinceController = TextEditingController(
      text: existing?.provinceName ?? '',
    );
    _districtController = TextEditingController(
      text: existing?.districtName ?? '',
    );
    _wardController = TextEditingController(text: existing?.wardName ?? '');
    _streetController = TextEditingController(
      text: existing?.streetAddress ?? '',
    );
    _noteController = TextEditingController(text: existing?.addressNote ?? '');
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _wardController.dispose();
    _streetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = addressFormViewModelProvider(widget.existing);
    final state = ref.watch(provider);

    ref.listen<AddressFormState>(provider, (previous, next) {
      if (next is AddressFormSuccess && context.mounted) {
        Navigator.of(context).pop(true);
      }
    });

    final form = state is AddressFormEditing
        ? state
        : const AddressFormEditing();
    final viewModel = ref.read(provider.notifier);
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);

    return ShopPageScaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ'),
      ),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          TextField(
            key: const Key('address_form_recipient'),
            controller: _recipientController,
            decoration: InputDecoration(
              labelText: 'Họ tên người nhận',
              errorText: form.recipientNameError,
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updateRecipientName,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('address_form_phone'),
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Số điện thoại',
              hintText: '0901234567',
              errorText: form.phoneNumberError,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updatePhoneNumber,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('address_form_province'),
            controller: _provinceController,
            decoration: InputDecoration(
              labelText: 'Tỉnh/Thành phố',
              errorText: form.provinceNameError,
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updateProvinceName,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('address_form_district'),
            controller: _districtController,
            decoration: InputDecoration(
              labelText: 'Quận/Huyện',
              errorText: form.districtNameError,
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updateDistrictName,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('address_form_ward'),
            controller: _wardController,
            decoration: InputDecoration(
              labelText: 'Phường/Xã',
              errorText: form.wardNameError,
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updateWardName,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('address_form_street'),
            controller: _streetController,
            decoration: InputDecoration(
              labelText: 'Địa chỉ cụ thể',
              errorText: form.streetAddressError,
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updateStreetAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('address_form_note'),
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (không bắt buộc)',
            ),
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            enabled: !form.isSubmitting,
            onChanged: viewModel.updateAddressNote,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            key: const Key('address_form_is_default'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Đặt làm địa chỉ mặc định'),
            value: form.isDefault,
            onChanged: form.isSubmitting
                ? null
                : (value) => viewModel.updateIsDefault(value: value),
          ),
          if (form.generalError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              form.generalError!,
              key: const Key('address_form_general_error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('address_form_submit'),
            onPressed: form.isSubmitting ? null : viewModel.submit,
            child: form.isSubmitting
                ? const SizedBox(
                    key: Key('address_form_submit_progress'),
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Lưu địa chỉ' : 'Thêm địa chỉ'),
          ),
        ],
      ),
    );
  }
}
