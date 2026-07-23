import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_text_field.dart';
import 'package:base_project/features/authentication/presentation/view_models/login_state.dart';
import 'package:base_project/features/authentication/presentation/view_models/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginForm extends ConsumerWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginViewModelProvider);
    final form = state is LoginFormState ? state : const LoginFormState();
    final viewModel = ref.read(loginViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassTextField(
          key: const Key('login_email_field'),
          label: 'Email',
          errorText: form.emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !form.isSubmitting,
          prefixIcon: const Icon(Icons.mail_outline),
          onChanged: viewModel.updateEmail,
        ),
        const SizedBox(height: 16),
        GlassTextField(
          key: const Key('login_password_field'),
          label: 'Password',
          errorText: form.passwordError,
          obscureText: !form.isPasswordVisible,
          textInputAction: TextInputAction.done,
          enabled: !form.isSubmitting,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            key: const Key('login_password_visibility'),
            onPressed: form.isSubmitting
                ? null
                : viewModel.togglePasswordVisibility,
            icon: Icon(
              form.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            ),
          ),
          onChanged: viewModel.updatePassword,
          onSubmitted: (_) => viewModel.login(),
        ),
        if (form.generalError != null) ...[
          const SizedBox(height: 12),
          Text(
            form.generalError!,
            key: const Key('login_general_error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        GlassButton(
          key: const Key('login_submit_button'),
          label: 'Sign in',
          isLoading: form.isSubmitting,
          onPressed: form.isSubmitting ? null : viewModel.login,
        ),
      ],
    );
  }
}
