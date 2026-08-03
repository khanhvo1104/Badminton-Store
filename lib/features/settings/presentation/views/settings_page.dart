import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/core/ui/glass/glass_chip.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceSettingsProvider);
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    final notifier = ref.read(appearanceSettingsProvider.notifier);

    return GlassBackground(
      enableAmbientMotion: appearance.ambientAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const GlassAppBar(title: Text('Settings')),
        body: ListView(
          padding: AppSpacing.page,
          children: [
            Text('Appearance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Theme mode', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {appearance.themeMode},
                    onSelectionChanged: (selection) {
                      notifier.setThemeMode(selection.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Liquid Glass', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Glass quality', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final quality in GlassQuality.values)
                        GlassChip(
                          key: Key('glass_quality_${quality.name}'),
                          label: quality.label,
                          selected: appearance.glassQuality == quality,
                          onTap: () => notifier.setGlassQuality(quality),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reduce motion'),
                      value: appearance.reduceMotion,
                      onChanged: (value) =>
                          notifier.setReduceMotion(value: value),
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ambient background animation'),
                      value: appearance.ambientAnimation,
                      onChanged: appearance.reduceMotion
                          ? null
                          : (value) =>
                                notifier.setAmbientAnimation(value: value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassButton(
              key: const Key('logout_button'),
              label: 'Log out',
              variant: GlassButtonVariant.destructive,
              icon: Icons.logout,
              onPressed: () => ref.read(authSessionProvider.notifier).logout(),
            ),
            const SizedBox(height: 16),
            Text('Environment', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(config.environment.displayName),
                  subtitle: Text(config.apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Architecture', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const GlassCard(
              child: Text(
                'Feature-first MVVM with selective use cases, '
                'repository interfaces in domain, and Riverpod DI. '
                'Liquid Glass is a ThemeExtension-driven design system.',
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              GlassButton(
                label: 'Open design system',
                variant: GlassButtonVariant.secondary,
                onPressed: () => context.push('/design-system'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
