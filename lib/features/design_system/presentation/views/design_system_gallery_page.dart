import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_avatar.dart';
import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/core/ui/glass/glass_chip.dart';
import 'package:base_project/core/ui/glass/glass_dialog.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_icon_button.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/core/ui/glass/glass_panel.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/core/ui/glass/glass_sheet.dart';
import 'package:base_project/core/ui/glass/glass_text_field.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:base_project/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesignSystemGalleryPage extends ConsumerWidget {
  const DesignSystemGalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceSettingsProvider);
    final notifier = ref.read(appearanceSettingsProvider.notifier);

    return GlassBackground(
      enableAmbientMotion: appearance.ambientAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const GlassAppBar(title: Text('Design System')),
        body: ListView(
          padding: AppSpacing.page,
          children: [
            Text('Controls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final mode in ThemeMode.values)
                        GlassChip(
                          label: mode.name,
                          selected: appearance.themeMode == mode,
                          onTap: () => notifier.setThemeMode(mode),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final q in GlassQuality.values)
                        GlassChip(
                          label: q.label,
                          selected: appearance.glassQuality == q,
                          onTap: () => notifier.setGlassQuality(q),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce motion'),
                    value: appearance.reduceMotion,
                    onChanged: (value) =>
                        notifier.setReduceMotion(value: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ambient animation'),
                    value: appearance.ambientAnimation,
                    onChanged: (value) =>
                        notifier.setAmbientAnimation(value: value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Surfaces', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const LiquidGlassContainer(
              enableBlur: true,
              elevated: true,
              padding: EdgeInsets.all(16),
              child: Text('LiquidGlassContainer with blur'),
            ),
            const SizedBox(height: 12),
            const GlassPanel(child: Text('GlassPanel')),
            const SizedBox(height: 12),
            const GlassCard(child: Text('GlassCard (no per-item blur)')),
            const SizedBox(height: 20),
            Text('Controls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GlassButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: 8),
            GlassButton(
              label: 'Secondary',
              variant: GlassButtonVariant.secondary,
              onPressed: () {},
            ),
            const SizedBox(height: 8),
            const GlassButton(
              label: 'Loading',
              isLoading: true,
              onPressed: null,
            ),
            const SizedBox(height: 8),
            const GlassButton(label: 'Disabled', onPressed: null),
            const SizedBox(height: 8),
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.favorite_border,
                  tooltip: 'Favorite',
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.notifications_outlined,
                  tooltip: 'Alerts',
                  badgeCount: 3,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            const GlassTextField(label: 'Sample field'),
            const SizedBox(height: 8),
            const GlassTextField(
              label: 'With error',
              errorText: 'Validation message',
            ),
            const SizedBox(height: 20),
            Text('Feedback', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const GlassAvatar(initials: 'DU', showStatus: true),
            const SizedBox(height: 12),
            const SizedBox(height: 72, child: GlassLoadingIndicator()),
            const SizedBox(height: 12),
            GlassErrorView(message: 'Sample error', onRetry: () {}),
            const SizedBox(height: 12),
            GlassButton(
              label: 'Show dialog',
              variant: GlassButtonVariant.secondary,
              onPressed: () => showGlassDialog<void>(
                context: context,
                title: 'Glass dialog',
                description: 'Accessible dialog with glass panel.',
                cancelLabel: 'Cancel',
              ),
            ),
            const SizedBox(height: 8),
            GlassButton(
              label: 'Show sheet',
              variant: GlassButtonVariant.secondary,
              onPressed: () => showGlassSheet<void>(
                context: context,
                builder: (context) => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Glass sheet content'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
