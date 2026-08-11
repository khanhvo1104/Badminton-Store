import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/ui/glass/glass_app_bar.dart';
import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_error_view.dart';
import 'package:base_project/core/ui/glass/glass_loading_indicator.dart';
import 'package:base_project/features/notifications/presentation/view_models/notifications_state.dart';
import 'package:base_project/features/notifications/presentation/view_models/notifications_view_model.dart';
import 'package:base_project/features/notifications/presentation/widgets/notification_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const double _loadMoreExtentThreshold = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsViewModelProvider);
    final viewModel = ref.read(notificationsViewModelProvider.notifier);

    ref.listen<NotificationsState>(notificationsViewModelProvider, (
      previous,
      next,
    ) {
      if (!context.mounted) {
        return;
      }
      final feedback = switch (next) {
        NotificationsContent(:final actionFeedback) => actionFeedback,
        _ => null,
      };
      if (feedback == null) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      viewModel.clearActionFeedback();
    });

    final showMarkAllRead = switch (state) {
      NotificationsContent(:final hasUnread, :final isMarkingAllRead) =>
        hasUnread && !isMarkingAllRead,
      _ => false,
    };
    final markAllBusy = state is NotificationsContent && state.isMarkingAllRead;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: const Text('Notifications'),
          leading: IconButton(
            key: const Key('notifications_back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              }
            },
          ),
          actions: [
            if (showMarkAllRead || markAllBusy)
              TextButton(
                key: const Key('notifications_mark_all_read'),
                onPressed: markAllBusy ? null : viewModel.markAllRead,
                child: markAllBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mark all read'),
              ),
          ],
        ),
        body: switch (state) {
          NotificationsLoading() => const _NotificationsLoadingBody(),
          NotificationsFailure(:final message) => _NotificationsFailureBody(
            message: message,
            onRetry: viewModel.retry,
          ),
          NotificationsContent() => _NotificationsContentBody(
            state: state,
            onRefresh: viewModel.refresh,
            onLoadMore: viewModel.loadMore,
            onMarkRead: viewModel.markRead,
            onRetryPagination: viewModel.loadMore,
          ),
        },
      ),
    );
  }
}

class _NotificationsLoadingBody extends StatelessWidget {
  const _NotificationsLoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('notifications_loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Semantics(
          label: 'Loading notifications',
          child: const GlassLoadingIndicator(
            message: 'Loading notifications...',
          ),
        ),
      ],
    );
  }
}

class _NotificationsFailureBody extends StatelessWidget {
  const _NotificationsFailureBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('notifications_error'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Semantics(
            label: 'Notifications error',
            child: GlassErrorView(message: message, onRetry: null),
          ),
        ),
        Center(
          child: TextButton(
            key: const Key('notifications_retry'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class _NotificationsContentBody extends StatelessWidget {
  const _NotificationsContentBody({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onMarkRead,
    required this.onRetryPagination,
  });

  final NotificationsContent state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onMarkRead;
  final VoidCallback onRetryPagination;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter <
              NotificationsPage._loadMoreExtentThreshold) {
            onLoadMore();
          }
          return false;
        },
        child: state.isEmpty
            ? ListView(
                key: const Key('notifications_empty'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                  Semantics(
                    label: 'No notifications',
                    child: const Center(
                      child: Text(NotificationsUiMessages.empty),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                key: const Key('notifications_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return _NotificationsListFooter(
                      state: state,
                      onRetryPagination: onRetryPagination,
                    );
                  }

                  final notification = state.items[index];
                  return NotificationListItem(
                    notification: notification,
                    isMarkingRead: state.markingReadIds.contains(
                      notification.id,
                    ),
                    onTap: () {
                      if (!notification.isRead) {
                        onMarkRead(notification.id);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationsListFooter extends StatelessWidget {
  const _NotificationsListFooter({
    required this.state,
    required this.onRetryPagination,
  });

  final NotificationsContent state;
  final VoidCallback onRetryPagination;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            key: Key('notifications_loading_more'),
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final paginationError = state.paginationError;
    if (paginationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Text(
              paginationError,
              key: const Key('notifications_pagination_error'),
              textAlign: TextAlign.center,
            ),
            TextButton(
              key: const Key('notifications_pagination_retry'),
              onPressed: onRetryPagination,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const SizedBox(height: AppSpacing.lg);
  }
}
