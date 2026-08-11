import 'dart:async';

import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:base_project/features/addresses/presentation/views/addresses_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAddressRepository extends Mock implements AddressRepository {}

Address _address({
  String id = 'addr-1',
  String name = 'Nguyen Van A',
  bool isDefault = false,
}) {
  return Address(
    id: id,
    userId: 'user-1',
    recipientName: name,
    phoneNumber: '0901234567',
    provinceName: 'Ho Chi Minh',
    districtName: 'Quan 1',
    wardName: 'Ben Nghe',
    streetAddress: '12 Nguyen Hue',
    isDefault: isDefault,
  );
}

void main() {
  late _MockAddressRepository repository;

  setUpAll(() {
    registerFallbackValue(_address());
  });

  setUp(() {
    repository = _MockAddressRepository();
  });

  Future<void> pumpAddresses(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [addressRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AddressesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('FAB opens empty form and does not create sample address', (
    tester,
  ) async {
    when(() => repository.list()).thenAnswer((_) async => const Success([]));

    await pumpAddresses(tester);

    expect(find.text('Thêm địa chỉ'), findsWidgets);
    expect(find.text('Thêm địa chỉ mẫu'), findsNothing);

    await tester.tap(find.byKey(const Key('addresses_add_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('address_form_recipient')), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsNothing);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('edit opens prefilled form and create validation shows errors', (
    tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => Success([_address(isDefault: true)]));

    await pumpAddresses(tester);

    expect(find.byKey(const Key('address_default_badge')), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa địa chỉ'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('0901234567'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addresses_add_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address_form_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập họ tên người nhận'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('create success closes form and refreshes list', (tester) async {
    var listed = false;
    when(() => repository.list()).thenAnswer((_) async {
      if (!listed) {
        listed = true;
        return const Success([]);
      }
      return Success([_address(id: 'new-1', name: 'Tran Van B')]);
    });
    when(() => repository.create(any())).thenAnswer(
      (_) async => Success(_address(id: 'new-1', name: 'Tran Van B')),
    );

    await pumpAddresses(tester);
    expect(find.text('Chưa có địa chỉ nào'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addresses_add_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('address_form_recipient')),
      'Tran Van B',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_phone')),
      '0901234567',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_province')),
      'Ha Noi',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_district')),
      'Ba Dinh',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_ward')),
      'Cong Vi',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_street')),
      '10 Kim Ma',
    );
    await tester.tap(find.byKey(const Key('address_form_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('address_form_recipient')), findsNothing);
    expect(find.text('Tran Van B'), findsOneWidget);
    verify(() => repository.create(any())).called(1);
  });

  testWidgets('delete cancel performs no mutation; confirm deletes', (
    tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => Success([_address()]));
    when(
      () => repository.delete('addr-1'),
    ).thenAnswer((_) async => const Success(null));

    await pumpAddresses(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('address_delete_cancel')));
    await tester.pumpAndSettle();
    verifyNever(() => repository.delete(any()));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address_delete_confirm')));
    await tester.pumpAndSettle();

    verify(() => repository.delete('addr-1')).called(1);
  });

  testWidgets('set default shows progress and refreshes only after success', (
    tester,
  ) async {
    final completer = Completer<Result<void>>();
    when(() => repository.list()).thenAnswer(
      (_) async => Success([
        _address(id: 'addr-1', isDefault: true),
        _address(id: 'addr-2', name: 'Other'),
      ]),
    );
    when(
      () => repository.setDefault('addr-2'),
    ).thenAnswer((_) => completer.future);

    await pumpAddresses(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt mặc định'));
    await tester.pump();

    expect(find.byKey(const Key('address_action_progress')), findsOneWidget);

    completer.complete(const Success(null));
    await tester.pumpAndSettle();
    verify(() => repository.setDefault('addr-2')).called(1);
  });

  testWidgets('create failure keeps form open with sanitized error', (
    tester,
  ) async {
    when(() => repository.list()).thenAnswer((_) async => const Success([]));
    when(() => repository.create(any())).thenAnswer(
      (_) async =>
          const Failure(DatabaseException('permission denied for table')),
    );

    await pumpAddresses(tester);
    await tester.tap(find.byKey(const Key('addresses_add_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('address_form_recipient')),
      'Tran Van B',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_phone')),
      '0901234567',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_province')),
      'Ha Noi',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_district')),
      'Ba Dinh',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_ward')),
      'Cong Vi',
    );
    await tester.enterText(
      find.byKey(const Key('address_form_street')),
      '10 Kim Ma',
    );
    await tester.tap(find.byKey(const Key('address_form_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('address_form_recipient')), findsOneWidget);
    expect(find.byKey(const Key('address_form_general_error')), findsOneWidget);
    expect(find.textContaining('permission denied'), findsNothing);
    expect(
      find.text('Không thể lưu địa chỉ. Vui lòng thử lại.'),
      findsOneWidget,
    );
  });
}
