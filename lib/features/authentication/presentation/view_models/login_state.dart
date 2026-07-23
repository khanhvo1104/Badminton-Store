sealed class LoginState {
  const LoginState();
}

final class LoginFormState extends LoginState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.emailError,
    this.passwordError,
    this.isPasswordVisible = false,
    this.isSubmitting = false,
    this.generalError,
  });

  final String email;
  final String password;
  final String? emailError;
  final String? passwordError;
  final bool isPasswordVisible;
  final bool isSubmitting;
  final String? generalError;

  LoginFormState copyWith({
    String? email,
    String? password,
    String? emailError,
    String? passwordError,
    bool? isPasswordVisible,
    bool? isSubmitting,
    String? generalError,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearGeneralError = false,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      emailError: clearEmailError ? null : emailError ?? this.emailError,
      passwordError: clearPasswordError
          ? null
          : passwordError ?? this.passwordError,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      generalError: clearGeneralError
          ? null
          : generalError ?? this.generalError,
    );
  }
}

final class LoginSuccess extends LoginState {
  const LoginSuccess();
}
