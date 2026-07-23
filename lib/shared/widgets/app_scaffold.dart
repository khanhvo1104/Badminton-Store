import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_bottom_navigation.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:base_project/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    GlassDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    GlassDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
    GlassDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ambient = ref.watch(
      appearanceSettingsProvider.select((s) => s.ambientAnimation),
    );
    final desktop = Breakpoints.isDesktop(context);

    return GlassBackground(
      enableAmbientMotion: ambient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: desktop
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: navigationShell.goBranch,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Colors.transparent,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  Expanded(child: ClipRect(child: navigationShell)),
                ],
              )
            : ClipRect(child: navigationShell),
        bottomNavigationBar: desktop
            ? null
            : GlassBottomNavigation(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: navigationShell.goBranch,
                destinations: destinations,
              ),
      ),
    );
  }
}
