import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core_providers.dart';
import '../../data/carpool_providers.dart';
import '../../data/models/chat.dart';

/// The driver's conversation threads, latest first. Subscribes to the shared
/// socket's `chat.message.received` while mounted and re-fetches on any incoming
/// message — **WS is a notifier, REST is the truth** — so unread counts and the
/// latest-message preview stay accurate.
class ChatThreadsController extends AsyncNotifier<List<ChatThread>> {
  void Function(dynamic)? _handler;

  @override
  Future<List<ChatThread>> build() async {
    final socket = ref.read(driverSocketProvider);
    void handler(dynamic _) => refresh();
    _handler = handler;
    socket.on('chat.message.received', handler);
    ref.onDispose(() => socket.off('chat.message.received', _handler));
    return ref.read(chatApiProvider).threads();
  }

  /// Re-loads the thread list (pull-to-refresh, and on every incoming message).
  Future<void> refresh() async {
    final threads = await AsyncValue.guard(
      () => ref.read(chatApiProvider).threads(),
    );
    // Keep the existing list visible on a transient error rather than blanking.
    if (threads is AsyncError && state.hasValue) return;
    state = threads;
  }
}

final chatThreadsControllerProvider =
    AsyncNotifierProvider<ChatThreadsController, List<ChatThread>>(
      ChatThreadsController.new,
    );

/// Total unread messages across all threads — drives the home/chat badge.
final unreadChatCountProvider = Provider<int>((ref) {
  final threads = ref.watch(chatThreadsControllerProvider).value;
  if (threads == null) return 0;
  return threads.fold<int>(0, (sum, t) => sum + t.unread);
});
