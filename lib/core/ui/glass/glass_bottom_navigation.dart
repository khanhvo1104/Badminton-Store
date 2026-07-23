import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/app/theme/app_radius.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:flutter/material.dart';

class GlassDestination {
  const GlassDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class GlassBottomNavigation extends StatelessWidget {
  const GlassBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlassDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isTabletOrLarger(context);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        // heightFactor keeps the bar sized to its child so the scaffold body
        // retains vertical space (bare Align would expand and collapse the body).
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 520 : double.infinity),
          child: LiquidGlassContainer(
            elevated: true,
            enableBlur: true,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: selectedIndex == i,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final GlassDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.standard,
          curve: AppMotion.standardCurve,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
