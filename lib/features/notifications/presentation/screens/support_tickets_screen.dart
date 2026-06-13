import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/support.dart';
import '../controllers/support_tickets_controller.dart';

/// The driver's support tickets, newest first. FAB opens a new ticket; tapping a
/// ticket opens its thread.
class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
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
      ref.read(supportTicketsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportTicketsControllerProvider);
    final controller = ref.read(supportTicketsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        actions: [
          IconButton(
            tooltip: 'Help center',
            icon: const Icon(Icons.help_outline),
            onPressed: () => context.push('/help'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/support/new');
          if (created == true) unawaited(controller.refresh());
        },
        icon: const Icon(Icons.add),
        label: const Text('New ticket'),
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: controller.refresh,
        ),
        data: (state) {
          if (state.tickets.isEmpty) {
            return const EmptyState(
              icon: Icons.support_agent,
              title: 'No tickets',
              message: 'Open a ticket and our team will get back to you.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: _scroll,
              padding: AppSpacing.screen,
              itemCount: state.tickets.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= state.tickets.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _TicketTile(ticket: state.tickets[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/support/${ticket.id}'),
        title: Text(
          ticket.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${ticket.category.label} · ${ticket.updatedAt.toFriendly()}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: StatusBadge(
          label: ticket.status.label,
          tone: ticket.status.tone,
        ),
      ),
    );
  }
}
