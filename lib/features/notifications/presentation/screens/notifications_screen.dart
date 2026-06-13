import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/app_notification.dart';
import '../controllers/notifications_controller.dart';

/// The in-app notification inbox: newest first, tap to open the deep link and
/// mark read, with a "mark all read" action.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(notificationsControllerProvider.notifier).loadMore();
    }
  }

  void _open(AppNotification n) {
    ref.read(notificationsControllerProvider.notifier).markRead(n.id);
    final link = n.deepLink;
    if (link != null && link.startsWith('/')) {
      context.push(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await controller.markAllRead();
              } catch (e) {
                if (context.mounted) context.showErrorSnack(e);
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: controller.refresh,
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              message: 'Trip, payment and safety alerts will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: _scroll,
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _NotificationTile(
                  notification: state.items[index],
                  onTap: () => _open(state.items[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: unread
            ? AppColors.brand.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          notification.icon,
          color: unread ? AppColors.brand : theme.colorScheme.outline,
        ),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 2),
          Text(
            notification.createdAt.toFriendly(),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
      isThreeLine: true,
      trailing: unread
          ? const Icon(Icons.circle, size: 10, color: AppColors.brand)
          : null,
    );
  }
}
