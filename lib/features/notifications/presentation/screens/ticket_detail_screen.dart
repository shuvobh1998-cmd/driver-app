import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/support.dart';
import '../../data/notifications_providers.dart';
import '../controllers/support_tickets_controller.dart';

/// A support ticket with its message thread and a reply composer (disabled once
/// the ticket is resolved/closed).
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportApiProvider).reply(widget.ticketId, body);
      _reply.clear();
      ref.invalidate(ticketDetailProvider(widget.ticketId));
      unawaited(ref.read(supportTicketsControllerProvider.notifier).refresh());
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketDetailProvider(widget.ticketId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(ticketDetailProvider(widget.ticketId)),
        ),
        data: (ticket) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(ticketDetailProvider(widget.ticketId)),
                child: ListView(
                  padding: AppSpacing.screen,
                  children: [
                    _Header(ticket: ticket),
                    const SizedBox(height: AppSpacing.md),
                    _OriginalMessage(ticket: ticket),
                    for (final m in ticket.messages) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MessageBubble(message: m),
                    ],
                  ],
                ),
              ),
            ),
            if (ticket.status.isActive)
              _ReplyComposer(
                controller: _reply,
                sending: _sending,
                onSend: _send,
              )
            else
              const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'This ticket is closed. Open a new one if you still need help.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ticket.subject,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusBadge(label: ticket.status.label, tone: ticket.status.tone),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${ticket.category.label} · opened ${ticket.createdAt.toFriendly()}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _OriginalMessage extends StatelessWidget {
  const _OriginalMessage({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(ticket.description),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = message.isStaff;
    return Align(
      alignment: staff ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: staff
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staff ? 'Support' : 'You',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(message.body),
            const SizedBox(height: 2),
            Text(
              message.createdAt.toFriendly(),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write a reply',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
