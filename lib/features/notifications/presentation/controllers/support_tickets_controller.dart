import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/support.dart';
import '../../data/notifications_providers.dart';

/// A page of the driver's support tickets plus paging flags.
class SupportTicketsState {
  const SupportTicketsState({
    this.tickets = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<Ticket> tickets;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  SupportTicketsState copyWith({
    List<Ticket>? tickets,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => SupportTicketsState(
    tickets: tickets ?? this.tickets,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The driver's support tickets, newest first, paginated.
class SupportTicketsController extends AsyncNotifier<SupportTicketsState> {
  static const _pageSize = 20;

  @override
  Future<SupportTicketsState> build() => _load(1);

  Future<SupportTicketsState> _load(int page) async {
    final tickets = await ref
        .read(supportApiProvider)
        .myTickets(page: page, pageSize: _pageSize);
    return SupportTicketsState(
      tickets: tickets,
      page: page,
      hasMore: tickets.length == _pageSize,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(1));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(supportApiProvider)
          .myTickets(page: current.page + 1, pageSize: _pageSize);
      state = AsyncData(
        current.copyWith(
          tickets: [...current.tickets, ...next],
          page: current.page + 1,
          hasMore: next.length == _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final supportTicketsControllerProvider =
    AsyncNotifierProvider<SupportTicketsController, SupportTicketsState>(
      SupportTicketsController.new,
    );
