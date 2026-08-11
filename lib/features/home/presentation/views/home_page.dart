import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/core/ui/responsive/breakpoints.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:base_project/features/home/presentation/view_models/home_state.dart';
import 'package:base_project/features/home/presentation/view_models/home_view_model.dart';
import 'package:base_project/features/home/presentation/widgets/featured_product_card.dart';
import 'package:base_project/shared/providers/current_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final userName = ref.watch(
      currentUserProvider.select((user) => user?.displayName ?? 'there'),
    );
    final wide = Breakpoints.isTabletOrLarger(context);

    ref.listen<HomeState>(homeViewModelProvider, (previous, next) {
      if (!context.mounted) {
        return;
      }
      final feedback = switch (next) {
        HomeLoaded(:final refreshFeedback) => refreshFeedback,
        HomeEmpty(:final refreshFeedback) => refreshFeedback,
        _ => null,
      };
      if (feedback == null) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      viewModel.clearRefreshFeedback();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: const Text('Home'),
        actions: [
          Semantics(
            button: true,
            label: HomeUiMessages.searchAction,
            child: IconButton(
              key: const Key('home_search_action'),
              tooltip: HomeUiMessages.searchAction,
              icon: const Icon(Icons.search),
              onPressed: () => context.push(AppRoutes.search),
            ),
          ),
          Semantics(
            button: true,
            label: HomeUiMessages.catalogAction,
            child: IconButton(
              key: const Key('home_catalog_action'),
              tooltip: HomeUiMessages.catalogAction,
              icon: const Icon(Icons.grid_view_outlined),
              onPressed: () => context.push(AppRoutes.catalog),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: switch (homeState) {
          HomeInitial() || HomeLoading() => const _HomeLoadingBody(),
          HomeEmpty() => _HomeEmptyBody(
            onBrowseCatalog: () => context.push(AppRoutes.catalog),
          ),
          HomeError(:final message) => _HomeErrorBody(
            message: message,
            onRetry: viewModel.retry,
          ),
          HomeLoaded(:final items) => _HomeLoadedBody(
            userName: userName,
            items: items,
            wide: wide,
            onOpenProduct: (id) => context.push(AppRoutes.productDetail(id)),
            onBrowseCatalog: () => context.push(AppRoutes.catalog),
            onOpenSearch: () => context.push(AppRoutes.search),
          ),
        },
      ),
    );
  }
}

class _HomeLoadingBody extends StatelessWidget {
  const _HomeLoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home_loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Semantics(
          label: HomeUiMessages.loading,
          child: const GlassLoadingIndicator(message: HomeUiMessages.loading),
        ),
      ],
    );
  }
}

class _HomeEmptyBody extends StatelessWidget {
  const _HomeEmptyBody({required this.onBrowseCatalog});

  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home_empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: AppSpacing.page,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_tennis_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      HomeUiMessages.emptyTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      HomeUiMessages.emptyMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GlassButton(
                      key: const Key('home_empty_catalog'),
                      label: HomeUiMessages.browseCatalog,
                      icon: Icons.grid_view_outlined,
                      onPressed: onBrowseCatalog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeErrorBody extends StatelessWidget {
  const _HomeErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home_error'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Semantics(
            label: 'Home error',
            child: GlassErrorView(message: message, onRetry: null),
          ),
        ),
        Center(
          child: TextButton(
            key: const Key('home_retry'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class _HomeLoadedBody extends StatelessWidget {
  const _HomeLoadedBody({
    required this.userName,
    required this.items,
    required this.wide,
    required this.onOpenProduct,
    required this.onBrowseCatalog,
    required this.onOpenSearch,
  });

  final String userName;
  final List<DashboardItem> items;
  final bool wide;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onBrowseCatalog;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      key: const Key('home_loaded'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.page,
      children: [
        Text(
          'Hello, $userName',
          key: const Key('home_greeting'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(HomeUiMessages.subtitle, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Semantics(
              button: true,
              label: HomeUiMessages.catalogAction,
              child: OutlinedButton.icon(
                key: const Key('home_catalog_button'),
                onPressed: onBrowseCatalog,
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text(HomeUiMessages.catalogAction),
              ),
            ),
            Semantics(
              button: true,
              label: HomeUiMessages.searchAction,
              child: OutlinedButton.icon(
                key: const Key('home_search_button'),
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search),
                label: const Text(HomeUiMessages.searchAction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          HomeUiMessages.featuredSection,
          key: const Key('home_featured_section'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final useGrid =
                wide &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth >= 480;
            if (!useGrid) {
              return Column(
                children: [
                  for (final item in items) ...[
                    FeaturedProductCard(
                      key: Key('home_featured_item_${item.id}'),
                      item: item,
                      onTap: () => onOpenProduct(item.id),
                    ),
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
                    child: FeaturedProductCard(
                      key: Key('home_featured_item_${item.id}'),
                      item: item,
                      onTap: () => onOpenProduct(item.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
