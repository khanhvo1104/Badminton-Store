import 'package:base_project/features/authentication/data/models/auth_response_model.dart';
import 'package:base_project/features/authentication/data/models/login_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  String? get currentAccessToken;

  Future<AuthResponseModel> login(LoginRequestModel request);

  Future<UserModel?> getCurrentUser();

  Future<void> logout();
}
