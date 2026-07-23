import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:base_project/features/home/presentation/view_models/home_view_model.dart';
import 'package:base_project/features/home/presentation/widgets/dashboard_card.dart';
import 'package:base_project/shared/providers/current_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final userName = ref.watch(
      currentUserProvider.select((user) => user?.displayName ?? 'there'),
    );
    final wide = Breakpoints.isTabletOrLarger(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const GlassAppBar(title: Text('Home')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeViewModelProvider.notifier).refresh(),
        child: switch (homeState) {
          HomeInitial() || HomeLoading() => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 160),
              GlassLoadingIndicator(message: 'Loading dashboard...'),
            ],
          ),
          HomeEmpty() => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: GlassErrorView(
                  title: 'Nothing here yet',
                  message: 'No dashboard items yet',
                  icon: Icons.inbox_outlined,
                  onRetry: () =>
                      ref.read(homeViewModelProvider.notifier).retry(),
                ),
              ),
            ],
          ),
          HomeError(:final message) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: GlassErrorView(
                  message: message,
                  onRetry: () =>
                      ref.read(homeViewModelProvider.notifier).retry(),
                ),
              ),
            ],
          ),
          HomeLoaded(:final items) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            children: [
              Text(
                'Hello, $userName',
                key: const Key('home_greeting'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Here is your overview',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              // Shared glass parent — cards themselves skip BackdropFilter.
              GlassCard(
                variant: GlassCardVariant.elevated,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final useGrid =
                        wide &&
                        constraints.maxWidth.isFinite &&
                        constraints.maxWidth >= 480;
                    if (!useGrid) {
                      return Column(
                        children: [
                          for (final item in items) ...[
                            DashboardCard(item: item),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }

                    final tileWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: tileWidth,
                            child: DashboardCard(item: item),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
