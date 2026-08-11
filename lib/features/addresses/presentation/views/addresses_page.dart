import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/presentation/view_models/addresses_actions_state.dart';
import 'package:base_project/features/addresses/presentation/view_models/addresses_actions_view_model.dart';
import 'package:base_project/features/addresses/presentation/views/address_form_page.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  Future<void> _openForm(BuildContext context, {Address? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressFormPage(existing: existing)),
    );
    if ((saved ?? false) && context.mounted) {
      final message = existing == null
          ? AddressesActionsUiMessages.createSuccess
          : AddressesActionsUiMessages.updateSuccess;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa địa chỉ'),
          content: Text(
            'Bạn có chắc muốn xóa địa chỉ của ${address.recipientName}?',
          ),
          actions: [
            TextButton(
              key: const Key('address_delete_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('address_delete_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref
        .read(addressesActionsViewModelProvider.notifier)
        .delete(address.id);
  }

  String _sanitizedListErrorMessage(Object error) {
    final raw = error is Exception
        ? error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')
        : '';
    if (raw == AddressesActionsUiMessages.unauthenticated ||
        raw == AddressesActionsUiMessages.network ||
        raw == AddressesActionsUiMessages.loadFailed) {
      return raw;
    }
    return AddressesActionsUiMessages.loadFailed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);
    final actionsState = ref.watch(addressesActionsViewModelProvider);
    final actionsBusy = actionsState is AddressesActionsBusy;

    ref.listen<AddressesActionsState>(addressesActionsViewModelProvider, (
      previous,
      next,
    ) {
      if (!context.mounted) {
        return;
      }
      final message = switch (next) {
        AddressesActionsFailure(:final message) => message,
        AddressesActionsSuccess(:final message) => message,
        _ => null,
      };
      if (message == null) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(addressesActionsViewModelProvider.notifier).clearFeedback();
    });

    return ShopPageScaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addresses_add_fab'),
        onPressed: actionsBusy ? null : () => _openForm(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm địa chỉ'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(addressesProvider);
          await ref.read(addressesProvider.future);
        },
        child: addressesAsync.when(
          data: (addresses) {
            if (addresses.isEmpty) {
              return ListView(
                key: const Key('addresses_empty_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Chưa có địa chỉ nào')),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                for (final address in addresses)
                  _AddressCard(
                    address: address,
                    busy:
                        actionsState is AddressesActionsBusy &&
                        actionsState.addressId == address.id,
                    actionsDisabled: actionsBusy,
                    onEdit: () => _openForm(context, existing: address),
                    onSetDefault: () {
                      ref
                          .read(addressesActionsViewModelProvider.notifier)
                          .setDefault(address.id);
                    },
                    onDelete: () => _confirmDelete(context, ref, address),
                  ),
              ],
            );
          },
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            key: const Key('addresses_error_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(
                  _sanitizedListErrorMessage(error),
                  key: const Key('addresses_list_error'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.actionsDisabled,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final Address address;
  final bool busy;
  final bool actionsDisabled;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(address.recipientName)),
            if (address.isDefault)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.xs),
                child: Chip(
                  key: Key('address_default_badge'),
                  label: Text('Mặc định'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.xs),
                child: SizedBox(
                  key: Key('address_action_progress'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${address.streetAddress}, ${address.wardName}, ${address.districtName}, ${address.provinceName}\n${address.phoneNumber}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !actionsDisabled,
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'default':
                onSetDefault();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            if (!address.isDefault)
              const PopupMenuItem(
                value: 'default',
                child: Text('Đặt mặc định'),
              ),
            const PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}
