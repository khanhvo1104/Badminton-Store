import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';

abstract interface class ProfileRepository {
  Future<Result<User>> getProfile();

  Future<Result<User>> updateDisplayName(String displayName);
}
