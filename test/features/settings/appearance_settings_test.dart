import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:base_project/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_container.dart';

void main() {
  test('appearance settings persist theme and glass quality', () async {
    final container = await createTestContainer();
    addTearDown(container.dispose);

    final sub = container.listen(
      appearanceSettingsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container
        .read(appearanceSettingsProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await container
        .read(appearanceSettingsProvider.notifier)
        .setGlassQuality(GlassQuality.low);
    await container
        .read(appearanceSettingsProvider.notifier)
        .setReduceMotion(value: true);
    await container
        .read(appearanceSettingsProvider.notifier)
        .setAmbientAnimation(value: false);

    final state = container.read(appearanceSettingsProvider);
    expect(state.themeMode, ThemeMode.dark);
    expect(state.glassQuality, GlassQuality.low);
    expect(state.reduceMotion, isTrue);
    expect(state.ambientAnimation, isFalse);
  });
}
