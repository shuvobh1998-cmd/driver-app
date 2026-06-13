import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/earnings_providers.dart';
import '../../data/models/payout.dart';

/// A page of payouts plus paging flags for the "load more" footer.
class PayoutsState {
  const PayoutsState({
    this.payouts = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<Payout> payouts;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  PayoutsState copyWith({
    List<Payout>? payouts,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => PayoutsState(
    payouts: payouts ?? this.payouts,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated payout history, newest first. The first page loads in [build];
/// [loadMore] appends until the backend returns a short page.
class PayoutsController extends AsyncNotifier<PayoutsState> {
  static const _pageSize = 20;

  @override
  Future<PayoutsState> build() => _load(1);

  Future<PayoutsState> _load(int page) async {
    final payouts = await ref
        .read(earningsApiProvider)
        .payouts(page: page, pageSize: _pageSize);
    return PayoutsState(
      payouts: payouts,
      page: page,
      hasMore: payouts.length == _pageSize,
    );
  }

  /// Re-loads from page 1 (pull-to-refresh, or after a new request lands).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(1));
  }

  /// Appends the next page. No-op while a load is in flight, on error, or once
  /// the end has been reached.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(earningsApiProvider)
          .payouts(page: current.page + 1, pageSize: _pageSize);
      state = AsyncData(
        current.copyWith(
          payouts: [...current.payouts, ...next],
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

final payoutsControllerProvider =
    AsyncNotifierProvider<PayoutsController, PayoutsState>(
      PayoutsController.new,
    );
