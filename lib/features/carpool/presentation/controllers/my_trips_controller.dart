import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/carpool_providers.dart';
import '../../data/models/carpool_enums.dart';
import '../../data/models/scheduled_trip.dart';

/// A page of the driver's posted carpool trips plus paging flags.
class MyTripsState {
  const MyTripsState({
    this.trips = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.filter,
  });

  final List<ScheduledTrip> trips;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Active status filter, or null for "all".
  final ScheduledTripStatus? filter;

  MyTripsState copyWith({
    List<ScheduledTrip>? trips,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    ScheduledTripStatus? filter,
    bool clearFilter = false,
  }) => MyTripsState(
    trips: trips ?? this.trips,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    filter: clearFilter ? null : (filter ?? this.filter),
  );
}

/// The driver's posted carpool trips, newest departure first, paginated and
/// filterable by status.
class MyTripsController extends AsyncNotifier<MyTripsState> {
  static const _pageSize = 20;

  @override
  Future<MyTripsState> build() => _load(1, null);

  Future<MyTripsState> _load(int page, ScheduledTripStatus? filter) async {
    final trips = await ref
        .read(carpoolApiProvider)
        .mine(page: page, pageSize: _pageSize, status: filter);
    return MyTripsState(
      trips: trips,
      page: page,
      hasMore: trips.length == _pageSize,
      filter: filter,
    );
  }

  /// Re-loads from page 1, keeping the current filter (pull-to-refresh).
  Future<void> refresh() async {
    final filter = state.value?.filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(1, filter));
  }

  /// Switches the status filter and reloads from page 1.
  Future<void> setFilter(ScheduledTripStatus? filter) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(1, filter));
  }

  /// Appends the next page. No-op while loading, on error, or at the end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(carpoolApiProvider)
          .mine(
            page: current.page + 1,
            pageSize: _pageSize,
            status: current.filter,
          );
      state = AsyncData(
        current.copyWith(
          trips: [...current.trips, ...next],
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

final myTripsControllerProvider =
    AsyncNotifierProvider<MyTripsController, MyTripsState>(
      MyTripsController.new,
    );
