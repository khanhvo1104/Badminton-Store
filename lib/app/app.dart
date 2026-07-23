import 'package:base_project/app/router/app_router.dart';
import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceSettingsProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Base Project',
      theme: AppTheme.light(quality: appearance.glassQuality),
      darkTheme: AppTheme.dark(quality: appearance.glassQuality),
      themeMode: appearance.themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                appearance.reduceMotion || media.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
