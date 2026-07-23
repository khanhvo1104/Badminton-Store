import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/utils/validators.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/authentication/domain/repositories/auth_repository.dart';

/// Login combines validation with authentication — a meaningful business action.
class LoginUseCase {
  const LoginUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<Result<User>> call({
    required String email,
    required String password,
  }) async {
    final emailError = Validators.email(email);
    final passwordError = Validators.password(password);

    if (emailError != null || passwordError != null) {
      return Failure(
        ValidationException(
          'Please fix the highlighted fields',
          fieldErrors: {
            if (emailError != null) 'email': emailError,
            if (passwordError != null) 'password': passwordError,
          },
        ),
      );
    }

    return _authRepository.login(email: email.trim(), password: password);
  }
}
