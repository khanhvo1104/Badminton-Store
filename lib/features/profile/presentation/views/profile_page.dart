import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_avatar.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/core/ui/glass/glass_panel.dart';
import 'package:base_project/core/ui/glass/glass_text_field.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_state.dart';
import 'package:base_project/features/profile/presentation/view_models/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassPanel(
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
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ProfileAccountEntry(
                      key: const Key('profile_account_orders'),
                      label: 'Orders',
                      icon: Icons.receipt_long_outlined,
                      onTap: () => context.push(AppRoutes.orders),
                    ),
                    _ProfileAccountEntry(
                      key: const Key('profile_account_addresses'),
                      label: 'Addresses',
                      icon: Icons.location_on_outlined,
                      onTap: () => context.push(AppRoutes.addresses),
                    ),
                    _ProfileAccountEntry(
                      key: const Key('profile_account_settings'),
                      label: 'Settings & logout',
                      icon: Icons.settings_outlined,
                      onTap: () => context.push(AppRoutes.settings),
                    ),
                  ],
                ),
              ),
            ),
          ),
      },
    );
  }
}

class _ProfileAccountEntry extends StatelessWidget {
  const _ProfileAccountEntry({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: GlassCard(
        variant: GlassCardVariant.interactive,
        onTap: onTap,
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
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
