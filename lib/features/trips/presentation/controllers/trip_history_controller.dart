import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/trip.dart';
import '../../data/trips_providers.dart';

/// A page of trip history plus whether more pages remain and a load-in-flight
/// flag for the "load more" footer.
class TripHistoryState {
  const TripHistoryState({
    this.trips = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<Trip> trips;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  TripHistoryState copyWith({
    List<Trip>? trips,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => TripHistoryState(
    trips: trips ?? this.trips,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated driver trip history, newest first. The first page loads in [build];
/// [loadMore] appends the next page until the backend returns a short page.
class TripHistoryController extends AsyncNotifier<TripHistoryState> {
  static const _pageSize = 20;

  @override
  Future<TripHistoryState> build() => _load(1);

  Future<TripHistoryState> _load(int page) async {
    final trips = await ref
        .read(tripsApiProvider)
        .history(page: page, pageSize: _pageSize);
    return TripHistoryState(
      trips: trips,
      page: page,
      hasMore: trips.length == _pageSize,
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
          .read(tripsApiProvider)
          .history(page: current.page + 1, pageSize: _pageSize);
      state = AsyncData(
        current.copyWith(
          trips: [...current.trips, ...next],
          page: current.page + 1,
          hasMore: next.length == _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what we have; drop the spinner so the user can retry.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final tripHistoryControllerProvider =
    AsyncNotifierProvider<TripHistoryController, TripHistoryState>(
      TripHistoryController.new,
    );
