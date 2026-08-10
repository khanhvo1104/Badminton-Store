import 'package:meta/meta.dart';

/// Shop profile mapped 1:1 to `public.profiles` (`id` = `auth.users.id`).
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.isActive,
    this.fullName,
    this.phoneNumber,
    this.avatarPath,
    this.dateOfBirth,
    this.gender,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? fullName;
  final String? phoneNumber;
  final String? avatarPath;
  final DateTime? dateOfBirth;
  final String? gender;

  /// `customer` | `staff` | `admin` — never client-writable.
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? avatarPath,
    DateTime? dateOfBirth,
    String? gender,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarPath: avatarPath ?? this.avatarPath,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Profile &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            fullName == other.fullName &&
            phoneNumber == other.phoneNumber &&
            avatarPath == other.avatarPath &&
            dateOfBirth == other.dateOfBirth &&
            gender == other.gender &&
            role == other.role &&
            isActive == other.isActive &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    phoneNumber,
    avatarPath,
    dateOfBirth,
    gender,
    role,
    isActive,
    createdAt,
    updatedAt,
  );
}
