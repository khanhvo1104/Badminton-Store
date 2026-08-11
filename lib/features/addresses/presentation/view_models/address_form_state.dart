import 'package:meta/meta.dart';

/// UI state for the create/edit address form.
sealed class AddressFormState {
  const AddressFormState();
}

@immutable
final class AddressFormEditing extends AddressFormState {
  const AddressFormEditing({
    this.editingAddressId,
    this.recipientName = '',
    this.phoneNumber = '',
    this.provinceName = '',
    this.districtName = '',
    this.wardName = '',
    this.streetAddress = '',
    this.addressNote = '',
    this.isDefault = false,
    this.recipientNameError,
    this.phoneNumberError,
    this.provinceNameError,
    this.districtNameError,
    this.wardNameError,
    this.streetAddressError,
    this.isSubmitting = false,
    this.generalError,
  });

  /// Non-null when editing an existing address; preserved across submit.
  final String? editingAddressId;
  final String recipientName;
  final String phoneNumber;
  final String provinceName;
  final String districtName;
  final String wardName;
  final String streetAddress;
  final String addressNote;
  final bool isDefault;
  final String? recipientNameError;
  final String? phoneNumberError;
  final String? provinceNameError;
  final String? districtNameError;
  final String? wardNameError;
  final String? streetAddressError;
  final bool isSubmitting;
  final String? generalError;

  bool get isEditing => editingAddressId != null;

  AddressFormEditing copyWith({
    String? editingAddressId,
    String? recipientName,
    String? phoneNumber,
    String? provinceName,
    String? districtName,
    String? wardName,
    String? streetAddress,
    String? addressNote,
    bool? isDefault,
    String? recipientNameError,
    String? phoneNumberError,
    String? provinceNameError,
    String? districtNameError,
    String? wardNameError,
    String? streetAddressError,
    bool? isSubmitting,
    String? generalError,
    bool clearRecipientNameError = false,
    bool clearPhoneNumberError = false,
    bool clearProvinceNameError = false,
    bool clearDistrictNameError = false,
    bool clearWardNameError = false,
    bool clearStreetAddressError = false,
    bool clearGeneralError = false,
    bool clearFieldErrors = false,
  }) {
    return AddressFormEditing(
      editingAddressId: editingAddressId ?? this.editingAddressId,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      provinceName: provinceName ?? this.provinceName,
      districtName: districtName ?? this.districtName,
      wardName: wardName ?? this.wardName,
      streetAddress: streetAddress ?? this.streetAddress,
      addressNote: addressNote ?? this.addressNote,
      isDefault: isDefault ?? this.isDefault,
      recipientNameError: clearFieldErrors || clearRecipientNameError
          ? null
          : recipientNameError ?? this.recipientNameError,
      phoneNumberError: clearFieldErrors || clearPhoneNumberError
          ? null
          : phoneNumberError ?? this.phoneNumberError,
      provinceNameError: clearFieldErrors || clearProvinceNameError
          ? null
          : provinceNameError ?? this.provinceNameError,
      districtNameError: clearFieldErrors || clearDistrictNameError
          ? null
          : districtNameError ?? this.districtNameError,
      wardNameError: clearFieldErrors || clearWardNameError
          ? null
          : wardNameError ?? this.wardNameError,
      streetAddressError: clearFieldErrors || clearStreetAddressError
          ? null
          : streetAddressError ?? this.streetAddressError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      generalError: clearFieldErrors || clearGeneralError
          ? null
          : generalError ?? this.generalError,
    );
  }
}

final class AddressFormSuccess extends AddressFormState {
  const AddressFormSuccess();
}
