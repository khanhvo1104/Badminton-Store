import 'package:base_project/core/config/demo_credentials.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_remote_data_source.dart';
import 'package:base_project/features/authentication/data/models/auth_response_model.dart';
import 'package:base_project/features/authentication/data/models/login_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';

/// Fake remote auth API. Swap for a Dio-backed implementation later.
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;

  @override
  String? get currentAccessToken => 'fake-access-token';

  UserModel _currentUser = const UserModel(
    id: 'user-001',
    email: DemoCredentials.email,
    displayName: 'Demo User',
  );

  @override
  Future<AuthResponseModel> login(LoginRequestModel request) async {
    await Future<void>.delayed(delay);

    if (request.email.toLowerCase() != DemoCredentials.email ||
        request.password != DemoCredentials.password) {
      throw const UnauthorizedException('Invalid email or password');
    }

    _currentUser = UserModel(
      id: 'user-001',
      email: request.email.toLowerCase(),
      displayName: 'Demo User',
    );

    return AuthResponseModel(
      accessToken: 'fake-access-token',
      user: _currentUser,
    );
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    await Future<void>.delayed(delay);
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(delay);
  }
}
