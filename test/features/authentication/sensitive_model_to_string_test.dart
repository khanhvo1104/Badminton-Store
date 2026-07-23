import 'package:base_project/features/authentication/data/models/auth_response_model.dart';
import 'package:base_project/features/authentication/data/models/login_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoginRequestModel toString redacts password', () {
    const model = LoginRequestModel(
      email: 'demo@example.com',
      password: 'Password123',
    );

    final text = model.toString();
    expect(text.contains('Password123'), isFalse);
    expect(text.contains('***'), isTrue);
    expect(text.contains('demo@example.com'), isTrue);
  });

  test('AuthResponseModel toString redacts access token', () {
    const model = AuthResponseModel(
      accessToken: 'super-secret-token',
      user: UserModel(id: '1', email: 'demo@example.com', displayName: 'Demo'),
    );

    final text = model.toString();
    expect(text.contains('super-secret-token'), isFalse);
    expect(text.contains('***'), isTrue);
  });
}
