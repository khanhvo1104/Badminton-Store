import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/di/auth_providers.dart';
import 'package:base_project/features/authentication/presentation/view_models/login_state.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginViewModel extends StateNotifier<LoginState> {
  LoginViewModel(this._ref) : super(const LoginFormState());

  final Ref _ref;

  LoginFormState get _form {
    final current = state;
    if (current is LoginFormState) {
      return current;
    }
    return const LoginFormState();
  }

  void updateEmail(String value) {
    state = _form.copyWith(
      email: value,
      clearEmailError: true,
      clearGeneralError: true,
    );
  }

  void updatePassword(String value) {
    state = _form.copyWith(
      password: value,
      clearPasswordError: true,
      clearGeneralError: true,
    );
  }

  void togglePasswordVisibility() {
    state = _form.copyWith(isPasswordVisible: !_form.isPasswordVisible);
  }

  void reset() {
    state = const LoginFormState();
  }

  Future<void> login() async {
    final form = _form;
    if (form.isSubmitting) {
      return;
    }

    state = form.copyWith(
      isSubmitting: true,
      clearEmailError: true,
      clearPasswordError: true,
      clearGeneralError: true,
    );

    final result = await _ref
        .read(loginUseCaseProvider)
        .call(email: form.email, password: form.password);

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success(data: final user):
        _ref.read(authSessionProvider.notifier).setAuthenticated(user);
        // Clear credentials from memory after success.
        state = const LoginSuccess();
      case Failure(error: final error):
        if (error is ValidationException) {
          state = form.copyWith(
            isSubmitting: false,
            emailError: error.fieldErrors['email'],
            passwordError: error.fieldErrors['password'],
            generalError: error.fieldErrors.isEmpty ? error.message : null,
          );
        } else {
          state = form.copyWith(
            isSubmitting: false,
            generalError: error.message,
          );
        }
    }
  }
}

final loginViewModelProvider =
    StateNotifierProvider.autoDispose<LoginViewModel, LoginState>((ref) {
      return LoginViewModel(ref);
    });
