import 'package:meta/meta.dart';

@immutable
class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.countryCode,
    this.line2,
    this.district,
    this.postalCode,
    this.isDefault = false,
    this.label,
  });

  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String? district;
  final String city;
  final String? postalCode;
  final String countryCode;
  final bool isDefault;
  final String? label;

  Address copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phone,
    String? line1,
    String? line2,
    String? district,
    String? city,
    String? postalCode,
    String? countryCode,
    bool? isDefault,
    String? label,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      district: district ?? this.district,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      countryCode: countryCode ?? this.countryCode,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Address &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            fullName == other.fullName &&
            phone == other.phone &&
            line1 == other.line1 &&
            line2 == other.line2 &&
            district == other.district &&
            city == other.city &&
            postalCode == other.postalCode &&
            countryCode == other.countryCode &&
            isDefault == other.isDefault &&
            label == other.label;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    fullName,
    phone,
    line1,
    line2,
    district,
    city,
    postalCode,
    countryCode,
    isDefault,
    label,
  );
}
