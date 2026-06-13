import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core_providers.dart';
import '../../data/models/app_notification.dart';
import '../../data/notifications_providers.dart';

/// A page of the inbox plus paging flags.
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => NotificationsState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The notification inbox, newest first, paginated. Subscribes to the shared
/// socket's `notification.received` while mounted and re-loads on a new push —
/// **WS is a notifier, REST is the truth**.
class NotificationsController extends AsyncNotifier<NotificationsState> {
  static const _pageSize = 20;
  void Function(dynamic)? _handler;

  @override
  Future<NotificationsState> build() async {
    final socket = ref.read(driverSocketProvider);
    void handler(dynamic _) => refresh();
    _handler = handler;
    socket.on('notification.received', handler);
    ref.onDispose(() => socket.off('notification.received', _handler));
    return _load(1);
  }

  Future<NotificationsState> _load(int page) async {
    final items = await ref
        .read(notificationsApiProvider)
        .inbox(page: page, pageSize: _pageSize);
    return NotificationsState(
      items: items,
      page: page,
      hasMore: items.length == _pageSize,
    );
  }

  /// Re-loads page 1 (pull-to-refresh, and on every incoming push).
  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => _load(1));
    if (next is AsyncError && state.hasValue) return; // keep what we have
    state = next;
    unawaited(ref.read(unreadCountControllerProvider.notifier).refresh());
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(notificationsApiProvider)
          .inbox(page: current.page + 1, pageSize: _pageSize);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next],
          page: current.page + 1,
          hasMore: next.length == _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Marks one notification read and patches it in place.
  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;
    final target = current.items.where((n) => n.id == id);
    if (target.isEmpty || target.first.read) return;
    try {
      final updated = await ref.read(notificationsApiProvider).markRead(id);
      state = AsyncData(
        current.copyWith(
          items: [
            for (final n in current.items)
              if (n.id == id) updated else n,
          ],
        ),
      );
      unawaited(ref.read(unreadCountControllerProvider.notifier).refresh());
    } catch (_) {
      // Leave the row unread; the next refresh reconciles.
    }
  }

  /// Marks everything read.
  Future<void> markAllRead() async {
    await ref.read(notificationsApiProvider).markAllRead();
    await refresh();
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

/// The unread count for the home bell badge. Refreshes on `notification.received`
/// and whenever the inbox marks rows read.
class UnreadCountController extends AsyncNotifier<int> {
  void Function(dynamic)? _handler;

  @override
  Future<int> build() async {
    final socket = ref.read(driverSocketProvider);
    void handler(dynamic _) => refresh();
    _handler = handler;
    socket.on('notification.received', handler);
    ref.onDispose(() => socket.off('notification.received', _handler));
    return ref.read(notificationsApiProvider).unreadCount();
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(
      () => ref.read(notificationsApiProvider).unreadCount(),
    );
    if (next is AsyncError && state.hasValue) return;
    state = next;
  }
}

final unreadCountControllerProvider =
    AsyncNotifierProvider<UnreadCountController, int>(
      UnreadCountController.new,
    );
