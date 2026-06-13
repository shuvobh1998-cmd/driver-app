import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/chat.dart';
import '../controllers/chat_threads_controller.dart';

/// The driver's chat threads, latest first, with live unread counts.
class ChatThreadsScreen extends ConsumerWidget {
  const ChatThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chatThreadsControllerProvider);
    final controller = ref.read(chatThreadsControllerProvider.notifier);

    return AppScaffold(
      title: 'Chats',
      padded: false,
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: controller.refresh,
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations',
              message: 'Messages with your carpool riders appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _ThreadTile(thread: threads[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = thread.unread > 0;
    return ListTile(
      onTap: () =>
          context.push('/chats/${thread.otherUserId}', extra: thread.name),
      leading: CircleAvatar(
        backgroundImage:
            (thread.avatarUrl != null && thread.avatarUrl!.isNotEmpty)
            ? NetworkImage(thread.avatarUrl!)
            : null,
        child: (thread.avatarUrl == null || thread.avatarUrl!.isEmpty)
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        thread.name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        thread.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: unread ? FontWeight.w600 : null,
          color: unread ? null : theme.colorScheme.outline,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            thread.lastMessageAt.toTimeOfDay(),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (unread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '${thread.unread}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
