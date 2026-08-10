import 'package:meta/meta.dart';

/// Vietnam-oriented shipping address (`public.addresses`).
@immutable
class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.recipientName,
    required this.phoneNumber,
    required this.provinceName,
    required this.districtName,
    required this.wardName,
    required this.streetAddress,
    this.provinceCode,
    this.districtCode,
    this.wardCode,
    this.addressNote,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String recipientName;
  final String phoneNumber;
  final String? provinceCode;
  final String provinceName;
  final String? districtCode;
  final String districtName;
  final String? wardCode;
  final String wardName;
  final String streetAddress;
  final String? addressNote;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Address copyWith({
    String? id,
    String? userId,
    String? recipientName,
    String? phoneNumber,
    String? provinceCode,
    String? provinceName,
    String? districtCode,
    String? districtName,
    String? wardCode,
    String? wardName,
    String? streetAddress,
    String? addressNote,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      provinceCode: provinceCode ?? this.provinceCode,
      provinceName: provinceName ?? this.provinceName,
      districtCode: districtCode ?? this.districtCode,
      districtName: districtName ?? this.districtName,
      wardCode: wardCode ?? this.wardCode,
      wardName: wardName ?? this.wardName,
      streetAddress: streetAddress ?? this.streetAddress,
      addressNote: addressNote ?? this.addressNote,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Address &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            recipientName == other.recipientName &&
            phoneNumber == other.phoneNumber &&
            provinceCode == other.provinceCode &&
            provinceName == other.provinceName &&
            districtCode == other.districtCode &&
            districtName == other.districtName &&
            wardCode == other.wardCode &&
            wardName == other.wardName &&
            streetAddress == other.streetAddress &&
            addressNote == other.addressNote &&
            isDefault == other.isDefault &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    recipientName,
    phoneNumber,
    provinceCode,
    provinceName,
    districtCode,
    districtName,
    wardCode,
    wardName,
    streetAddress,
    addressNote,
    isDefault,
    createdAt,
    updatedAt,
  );
}
