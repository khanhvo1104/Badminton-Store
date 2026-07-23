import 'package:meta/meta.dart';

/// Extended shop profile for the signed-in customer.
/// Distinct from auth `User`, which is the identity principal.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.locale,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? locale;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? locale,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locale: locale ?? this.locale,
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
            userId == other.userId &&
            displayName == other.displayName &&
            email == other.email &&
            phone == other.phone &&
            avatarUrl == other.avatarUrl &&
            locale == other.locale &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    displayName,
    email,
    phone,
    avatarUrl,
    locale,
    createdAt,
    updatedAt,
  );
}
