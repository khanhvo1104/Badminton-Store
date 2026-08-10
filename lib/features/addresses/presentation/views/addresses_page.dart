import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final addressesProvider = FutureProvider.autoDispose<List<Address>>((
  ref,
) async {
  final result = await ref.read(addressRepositoryProvider).list();
  return result.when(
    success: (data) => data,
    failure: (error) => throw Exception(error.message),
  );
});

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(addressRepositoryProvider);
          await repo.create(
            const Address(
              id: '',
              userId: '',
              recipientName: 'Nguyen Van A',
              phoneNumber: '0900000000',
              provinceName: 'Ho Chi Minh',
              districtName: 'Quan 1',
              wardName: 'Ben Nghe',
              streetAddress: '123 Demo Street',
              addressNote: 'Địa chỉ mẫu tạo từ app',
              isDefault: true,
            ),
          );
          ref.invalidate(addressesProvider);
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm địa chỉ mẫu'),
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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Chưa có địa chỉ nào')),
                ],
              );
            }
            return ListView(
              padding: AppSpacing.page,
              children: [
                for (final address in addresses)
                  Card(
                    child: ListTile(
                      title: Text(address.recipientName),
                      subtitle: Text(
                        '${address.streetAddress}, ${address.wardName}, ${address.districtName}, ${address.provinceName}\n${address.phoneNumber}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'default') {
                            await ref
                                .read(addressRepositoryProvider)
                                .setDefault(address.id);
                          } else if (value == 'delete') {
                            await ref
                                .read(addressRepositoryProvider)
                                .delete(address.id);
                          }
                          ref.invalidate(addressesProvider);
                        },
                        itemBuilder: (context) => [
                          if (!address.isDefault)
                            const PopupMenuItem(
                              value: 'default',
                              child: Text('Đặt mặc định'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Không tải được địa chỉ: $error')),
        ),
      ),
    );
  }
}
