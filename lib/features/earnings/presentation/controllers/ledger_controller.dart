import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/earnings_providers.dart';
import '../../data/models/ledger_entry.dart';

/// A page of wallet ledger entries plus paging flags for the "load more" footer.
class LedgerState {
  const LedgerState({
    this.entries = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<LedgerEntry> entries;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  LedgerState copyWith({
    List<LedgerEntry>? entries,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => LedgerState(
    entries: entries ?? this.entries,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated wallet ledger, newest first. The first page loads in [build];
/// [loadMore] appends until the backend returns a short page.
class LedgerController extends AsyncNotifier<LedgerState> {
  static const _pageSize = 20;

  @override
  Future<LedgerState> build() => _load(1);

  Future<LedgerState> _load(int page) async {
    final entries = await ref
        .read(earningsApiProvider)
        .ledger(page: page, pageSize: _pageSize);
    return LedgerState(
      entries: entries,
      page: page,
      hasMore: entries.length == _pageSize,
    );
  }

  /// Re-loads from page 1 (pull-to-refresh).
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
          .ledger(page: current.page + 1, pageSize: _pageSize);
      state = AsyncData(
        current.copyWith(
          entries: [...current.entries, ...next],
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

final ledgerControllerProvider =
    AsyncNotifierProvider<LedgerController, LedgerState>(LedgerController.new);
