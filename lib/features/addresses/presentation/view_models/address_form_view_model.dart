import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/presentation/view_models/address_form_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Vietnamese copy for address form validation and mutation failures.
abstract final class AddressFormUiMessages {
  static const recipientRequired = 'Vui lòng nhập họ tên người nhận';
  static const phoneRequired = 'Vui lòng nhập số điện thoại';
  static const phoneInvalid = 'Số điện thoại không hợp lệ. Ví dụ: 0901234567';
  static const provinceRequired = 'Vui lòng nhập tỉnh/thành phố';
  static const districtRequired = 'Vui lòng nhập quận/huyện';
  static const wardRequired = 'Vui lòng nhập phường/xã';
  static const streetRequired = 'Vui lòng nhập địa chỉ cụ thể';
  static const unauthenticated =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const network = 'Không thể kết nối. Vui lòng thử lại.';
  static const saveFailed = 'Không thể lưu địa chỉ. Vui lòng thử lại.';
}

class AddressFormViewModel extends StateNotifier<AddressFormState> {
  AddressFormViewModel(this._ref, {Address? existing})
    : super(
        existing == null
            ? const AddressFormEditing()
            : AddressFormEditing(
                editingAddressId: existing.id,
                recipientName: existing.recipientName,
                phoneNumber: existing.phoneNumber,
                provinceName: existing.provinceName,
                districtName: existing.districtName,
                wardName: existing.wardName,
                streetAddress: existing.streetAddress,
                addressNote: existing.addressNote ?? '',
                isDefault: existing.isDefault,
              ),
      );

  final Ref _ref;

  AddressFormEditing get _form {
    final current = state;
    if (current is AddressFormEditing) {
      return current;
    }
    return const AddressFormEditing();
  }

  void updateRecipientName(String value) {
    state = _form.copyWith(
      recipientName: value,
      clearRecipientNameError: true,
      clearGeneralError: true,
    );
  }

  void updatePhoneNumber(String value) {
    state = _form.copyWith(
      phoneNumber: value,
      clearPhoneNumberError: true,
      clearGeneralError: true,
    );
  }

  void updateProvinceName(String value) {
    state = _form.copyWith(
      provinceName: value,
      clearProvinceNameError: true,
      clearGeneralError: true,
    );
  }

  void updateDistrictName(String value) {
    state = _form.copyWith(
      districtName: value,
      clearDistrictNameError: true,
      clearGeneralError: true,
    );
  }

  void updateWardName(String value) {
    state = _form.copyWith(
      wardName: value,
      clearWardNameError: true,
      clearGeneralError: true,
    );
  }

  void updateStreetAddress(String value) {
    state = _form.copyWith(
      streetAddress: value,
      clearStreetAddressError: true,
      clearGeneralError: true,
    );
  }

  void updateAddressNote(String value) {
    state = _form.copyWith(addressNote: value, clearGeneralError: true);
  }

  void updateIsDefault({required bool value}) {
    state = _form.copyWith(isDefault: value, clearGeneralError: true);
  }

  Future<void> submit() async {
    final form = _form;
    if (form.isSubmitting) {
      return;
    }

    final validated = _validate(form);
    if (validated != null) {
      state = validated;
      return;
    }

    final recipientName = form.recipientName.trim();
    final phoneNumber = _normalizePhone(form.phoneNumber);
    final provinceName = form.provinceName.trim();
    final districtName = form.districtName.trim();
    final wardName = form.wardName.trim();
    final streetAddress = form.streetAddress.trim();
    final noteTrimmed = form.addressNote.trim();
    final addressNote = noteTrimmed.isEmpty ? null : noteTrimmed;

    // Block duplicate submission before the first await.
    state = form.copyWith(
      isSubmitting: true,
      clearFieldErrors: true,
      clearGeneralError: true,
    );

    // Ownership (`userId`) is intentionally empty — repository stamps auth user.
    final entity = Address(
      id: form.editingAddressId ?? '',
      userId: '',
      recipientName: recipientName,
      phoneNumber: phoneNumber,
      provinceName: provinceName,
      districtName: districtName,
      wardName: wardName,
      streetAddress: streetAddress,
      addressNote: addressNote,
      isDefault: form.isDefault,
    );

    final repository = _ref.read(addressRepositoryProvider);
    final Result<Address> result;
    if (form.isEditing) {
      result = await repository.update(entity);
    } else {
      result = await repository.create(entity);
    }

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success():
        _ref.invalidate(addressesProvider);
        state = const AddressFormSuccess();
      case Failure(error: final error):
        state = form.copyWith(
          isSubmitting: false,
          generalError: mapSaveFailure(error),
        );
    }
  }

  AddressFormEditing? _validate(AddressFormEditing form) {
    final recipientNameError = form.recipientName.trim().isEmpty
        ? AddressFormUiMessages.recipientRequired
        : null;
    final phoneNumberError = _validatePhone(form.phoneNumber);
    final provinceNameError = form.provinceName.trim().isEmpty
        ? AddressFormUiMessages.provinceRequired
        : null;
    final districtNameError = form.districtName.trim().isEmpty
        ? AddressFormUiMessages.districtRequired
        : null;
    final wardNameError = form.wardName.trim().isEmpty
        ? AddressFormUiMessages.wardRequired
        : null;
    final streetAddressError = form.streetAddress.trim().isEmpty
        ? AddressFormUiMessages.streetRequired
        : null;

    if (recipientNameError == null &&
        phoneNumberError == null &&
        provinceNameError == null &&
        districtNameError == null &&
        wardNameError == null &&
        streetAddressError == null) {
      return null;
    }

    return AddressFormEditing(
      editingAddressId: form.editingAddressId,
      recipientName: form.recipientName,
      phoneNumber: form.phoneNumber,
      provinceName: form.provinceName,
      districtName: form.districtName,
      wardName: form.wardName,
      streetAddress: form.streetAddress,
      addressNote: form.addressNote,
      isDefault: form.isDefault,
      recipientNameError: recipientNameError,
      phoneNumberError: phoneNumberError,
      provinceNameError: provinceNameError,
      districtNameError: districtNameError,
      wardNameError: wardNameError,
      streetAddressError: streetAddressError,
    );
  }

  /// Accepts common Vietnamese mobile local formats (`09xxxxxxxx`, optional
  /// spaces/dashes) and `+84` / `84` equivalents. Does not call the repository.
  @visibleForTesting
  static String? validatePhone(String raw) => _validatePhone(raw);

  static String? _validatePhone(String raw) {
    final normalized = _normalizePhone(raw);
    if (normalized.isEmpty) {
      return AddressFormUiMessages.phoneRequired;
    }
    if (!_vnLocalPhone.hasMatch(normalized) &&
        !_vnIntlPhone.hasMatch(normalized)) {
      return AddressFormUiMessages.phoneInvalid;
    }
    return null;
  }

  static String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[\s\-.]'), '');
  }

  /// Local: 03/05/07/08/09 + 8 digits.
  static final _vnLocalPhone = RegExp(r'^0[35789]\d{8}$');

  /// International: +84 or 84 + 3/5/7/8/9 + 8 digits.
  static final _vnIntlPhone = RegExp(r'^\+?84[35789]\d{8}$');

  @visibleForTesting
  static String mapSaveFailure(AppException error) {
    return switch (error) {
      UnauthorizedException() ||
      AuthenticationException() => AddressFormUiMessages.unauthenticated,
      NetworkException() => AddressFormUiMessages.network,
      _ => AddressFormUiMessages.saveFailed,
    };
  }
}

final addressFormViewModelProvider = StateNotifierProvider.autoDispose
    .family<AddressFormViewModel, AddressFormState, Address?>((ref, existing) {
      return AddressFormViewModel(ref, existing: existing);
    });
