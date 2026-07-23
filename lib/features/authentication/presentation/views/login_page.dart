import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/config/demo_credentials.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/core/ui/glass/glass_panel.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:base_project/features/authentication/presentation/widgets/login_form.dart';
import 'package:base_project/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showDemoHint = ref.watch(
      appConfigProvider.select((config) => config.enableDebugTools),
    );
    final ambient = ref.watch(
      appearanceSettingsProvider.select((s) => s.ambientAnimation),
    );

    return GlassBackground(
      enableAmbientMotion: ambient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Breakpoints.contentMaxWidth(context).isFinite
                    ? 440
                    : 440,
              ),
              child: SingleChildScrollView(
                padding: AppSpacing.pageWide,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Base Project',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      const LoginForm(),
                      if (showDemoHint) ...[
                        const SizedBox(height: 24),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Demo account',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Email: ${DemoCredentials.email}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                'Password: ${DemoCredentials.password}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
