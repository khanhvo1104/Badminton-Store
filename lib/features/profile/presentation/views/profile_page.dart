import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_avatar.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/core/ui/glass/glass_panel.dart';
import 'package:base_project/core/ui/glass/glass_text_field.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_state.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const GlassAppBar(title: Text('Profile')),
      body: switch (state) {
        ProfileInitial() || ProfileLoading() => const GlassLoadingIndicator(
          message: 'Loading profile...',
        ),
        ProfileError(:final message) => GlassErrorView(
          message: message,
          onRetry: () => ref.read(profileViewModelProvider.notifier).retry(),
        ),
        ProfileLoaded(
          :final user,
          :final isSaving,
          :final validationError,
          :final apiError,
          :final successMessage,
        ) =>
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Breakpoints.isDesktop(context) ? 520 : 480,
              ),
              child: SingleChildScrollView(
                padding: AppSpacing.page,
                child: GlassPanel(
                  child: _ProfileFormBody(
                    key: ValueKey(user.id),
                    email: user.email,
                    initialDisplayName: user.displayName,
                    isSaving: isSaving,
                    validationError: validationError,
                    apiError: apiError,
                    successMessage: successMessage,
                  ),
                ),
              ),
            ),
          ),
      },
    );
  }
}

class _ProfileFormBody extends ConsumerStatefulWidget {
  const _ProfileFormBody({
    required this.email,
    required this.initialDisplayName,
    required this.isSaving,
    super.key,
    this.validationError,
    this.apiError,
    this.successMessage,
  });

  final String email;
  final String initialDisplayName;
  final bool isSaving;
  final String? validationError;
  final String? apiError;
  final String? successMessage;

  @override
  ConsumerState<_ProfileFormBody> createState() => _ProfileFormBodyState();
}

class _ProfileFormBodyState extends ConsumerState<_ProfileFormBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDisplayName);
  }

  @override
  void didUpdateWidget(covariant _ProfileFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDisplayName != widget.initialDisplayName) {
      _controller.text = widget.initialDisplayName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(profileViewModelProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: GlassAvatar(
            initials: widget.initialDisplayName,
            showStatus: true,
          ),
        ),
        const SizedBox(height: 20),
        Text(widget.email, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GlassTextField(
          key: const Key('profile_display_name_field'),
          controller: _controller,
          label: 'Display name',
          errorText: widget.validationError,
          enabled: !widget.isSaving,
          onChanged: viewModel.updateDisplayNameDraft,
        ),
        if (widget.apiError != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.apiError!,
            key: const Key('profile_api_error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (widget.successMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.successMessage!,
            key: const Key('profile_success_message'),
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ],
        const SizedBox(height: 24),
        GlassButton(
          key: const Key('profile_save_button'),
          label: 'Save changes',
          isLoading: widget.isSaving,
          onPressed: widget.isSaving ? null : viewModel.save,
        ),
      ],
    );
  }
}
