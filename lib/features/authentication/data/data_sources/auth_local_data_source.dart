import 'package:base_project/shared/data/models/user_model.dart';

abstract interface class AuthLocalDataSource {
  Future<void> saveSession({
    required String accessToken,
    required UserModel user,
  });

  Future<String?> readAccessToken();

  Future<UserModel?> readCachedUser();

  Future<void> clearSession();
}
