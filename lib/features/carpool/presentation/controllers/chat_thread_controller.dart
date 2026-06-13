import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core_providers.dart';
import '../../data/carpool_providers.dart';
import '../../data/models/chat.dart';

/// Messages in one conversation, in chronological order (oldest first) for the
/// chat view, plus paging and send flags.
class ChatThreadState {
  const ChatThreadState({
    this.messages = const [],
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
    this.sending = false,
  });

  /// Oldest → newest, ready to render top-to-bottom.
  final List<ChatMessage> messages;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool sending;

  ChatThreadState copyWith({
    List<ChatMessage>? messages,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? sending,
  }) => ChatThreadState(
    messages: messages ?? this.messages,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    sending: sending ?? this.sending,
  );
}

/// One 1:1 conversation with `otherUserId`. Loads the latest page, marks the
/// thread read, and live-appends incoming `chat.message.received` events for this
/// peer while mounted.
class ChatThreadController extends AsyncNotifier<ChatThreadState> {
  ChatThreadController(this._otherUserId);

  static const _pageSize = 30;

  final String _otherUserId;
  void Function(dynamic)? _handler;

  @override
  Future<ChatThreadState> build() async {
    final socket = ref.read(driverSocketProvider);
    void handler(dynamic data) => _onIncoming(data);
    _handler = handler;
    socket.on('chat.message.received', handler);
    ref.onDispose(() => socket.off('chat.message.received', _handler));

    final newestFirst = await ref
        .read(chatApiProvider)
        .messages(_otherUserId, page: 1, pageSize: _pageSize);
    // Best-effort: clear unread for this thread on open.
    unawaitedMarkRead();
    return ChatThreadState(
      messages: newestFirst.reversed.toList(growable: false),
      page: 1,
      hasMore: newestFirst.length == _pageSize,
    );
  }

  void unawaitedMarkRead() {
    ref.read(chatApiProvider).markRead(_otherUserId).ignore();
  }

  /// Loads the previous (older) page and prepends it.
  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final older = await ref
          .read(chatApiProvider)
          .messages(_otherUserId, page: current.page + 1, pageSize: _pageSize);
      state = AsyncData(
        current.copyWith(
          messages: [...older.reversed, ...current.messages],
          page: current.page + 1,
          hasMore: older.length == _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Sends [text]; appends the persisted message returned by the backend.
  /// Throws on failure so the screen can surface it; the input is preserved.
  Future<void> send(String text, {String? scheduledTripId}) async {
    final body = text.trim();
    final current = state.value;
    if (body.isEmpty || current == null || current.sending) return;
    state = AsyncData(current.copyWith(sending: true));
    try {
      final sent = await ref
          .read(chatApiProvider)
          .send(
            toUserId: _otherUserId,
            message: body,
            scheduledTripId: scheduledTripId,
          );
      state = AsyncData(
        current.copyWith(
          messages: _appended(current.messages, sent),
          sending: false,
        ),
      );
    } catch (e) {
      state = AsyncData(current.copyWith(sending: false));
      rethrow;
    }
  }

  void _onIncoming(dynamic data) {
    final msg = ChatMessage.tryParse(data);
    if (msg == null || msg.otherUserId != _otherUserId) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(messages: _appended(current.messages, msg)),
    );
    unawaitedMarkRead();
  }

  /// Appends [msg] unless its id is already present (de-dupes the socket echo of
  /// a message we already added from the REST response).
  static List<ChatMessage> _appended(List<ChatMessage> list, ChatMessage msg) {
    if (list.any((m) => m.id == msg.id)) return list;
    return [...list, msg];
  }
}

final chatThreadControllerProvider =
    AsyncNotifierProvider.family<ChatThreadController, ChatThreadState, String>(
      ChatThreadController.new,
    );
// `ChatThreadController.new` is `Function(String)`, matching the Riverpod 3
// family create signature — the arg is injected via the constructor.
