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

  UserModel? _currentUser;
  String? _accessToken;

  @override
  String? get currentAccessToken => _accessToken;

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
    _accessToken = 'fake-access-token';

    return AuthResponseModel(accessToken: _accessToken!, user: _currentUser!);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    await Future<void>.delayed(delay);
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(delay);
    _currentUser = null;
    _accessToken = null;
  }
}
