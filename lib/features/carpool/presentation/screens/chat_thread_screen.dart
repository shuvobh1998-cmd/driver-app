import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../controllers/chat_thread_controller.dart';
import '../widgets/chat_bubble.dart';

/// One 1:1 conversation: message history (live) plus a composer. Pass an
/// optional [title] (the rider's name, when known) for the app bar.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.otherUserId, this.title});

  final String otherUserId;
  final String? title;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    // Older messages load when the list is pulled to the top.
    if (_scroll.position.pixels <= _scroll.position.minScrollExtent + 80) {
      ref
          .read(chatThreadControllerProvider(widget.otherUserId).notifier)
          .loadOlder();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final controller = ref.read(
      chatThreadControllerProvider(widget.otherUserId).notifier,
    );
    _input.clear();
    try {
      await controller.send(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        context.showErrorSnack(e);
        _input.text = text; // preserve the unsent message
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = chatThreadControllerProvider(widget.otherUserId);
    final async = ref.watch(provider);

    // Auto-scroll to the latest message as the thread grows.
    ref.listen(provider, (prev, next) {
      final prevLen = prev?.value?.messages.length ?? 0;
      final nextLen = next.value?.messages.length ?? 0;
      if (nextLen > prevLen) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Chat')),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(
                message: messageForError(e),
                onRetry: () => ref.invalidate(provider),
              ),
              data: (state) {
                if (state.messages.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message: 'Say hello to coordinate the pickup.',
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: AppSpacing.screen,
                  itemCount:
                      state.messages.length + (state.loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (state.loadingMore && i == 0) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final idx = state.loadingMore ? i - 1 : i;
                    return ChatBubble(message: state.messages[idx]);
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            sending: async.value?.sending ?? false,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
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
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message',
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
