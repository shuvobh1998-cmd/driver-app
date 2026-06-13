import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core_providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/location/live_location_service.dart';
import '../../../../core/websocket/driver_socket.dart';
import '../../data/models/trip.dart';
import '../../data/trips_api.dart';
import '../../data/trips_providers.dart';

/// Single source of truth for the driver's active trip. Holds the [Trip] through
/// its lifecycle (ACCEPTED → ARRIVED → STARTED → ENDED/CANCELLED) and exposes the
/// lifecycle actions, each of which reconciles against the [Trip] the server
/// returns.
///
/// While the trip is active the controller mirrors the location pump's samples
/// onto the socket as `trip.location`, so the rider sees the driver move. **WS is
/// a notifier, REST is the truth:** [reconcile] re-fetches over REST whenever a
/// `trip.*` event lands or the socket reconnects.
class ActiveTripController extends AsyncNotifier<Trip?> {
  TripsApi get _api => ref.read(tripsApiProvider);
  DriverSocket get _socket => ref.read(driverSocketProvider);

  StreamSubscription<LocationSample>? _locSub;

  @override
  Future<Trip?> build() async {
    ref.onDispose(() => _locSub?.cancel());
    final trip = await _api.currentTrip();
    _syncStreaming(trip);
    return trip;
  }

  /// Re-fetches the current active trip from REST (after accept, reconnect, or a
  /// WS notification that didn't carry an id).
  Future<void> loadCurrent() async {
    final trip = await _api.currentTrip();
    _syncStreaming(trip);
    state = AsyncData(trip);
  }

  /// Reconciles a specific trip from REST after a `trip.*` notification — covers
  /// terminal states (`ENDED`/`CANCELLED`) where `current` would already be null.
  Future<void> reconcile(String tripId) async {
    final current = state.value;
    // Ignore events for a trip we are not running, unless we have none.
    if (current != null && current.publicId != tripId) return;
    try {
      final trip = await _api.tripDetail(tripId);
      _syncStreaming(trip);
      state = AsyncData(trip);
    } catch (_) {
      await loadCurrent();
    }
  }

  Future<Trip> arrived() => _act((id) => _api.arrived(id));

  Future<Trip> startTrip(String otp) => _act((id) => _api.start(id, otp: otp));

  Future<Trip> endTrip() => _act((id) => _api.end(id));

  Future<Trip> cancelTrip({String? reason}) =>
      _act((id) => _api.cancel(id, reason: reason));

  /// Rates the rider once. The returned [Trip] reflects the stored rating so the
  /// UI can show it's done; a re-rate surfaces `ALREADY_RATED` from the backend.
  Future<Trip> rateRider({required int rating, String? comment}) async {
    final id = _requireTripId();
    final next = await _api.rateRider(id, rating: rating, comment: comment);
    state = AsyncData(next);
    return next;
  }

  /// Clears the finished trip from state (after the driver leaves the summary),
  /// returning home to the searching state.
  void clear() {
    _syncStreaming(null);
    state = const AsyncData(null);
  }

  /// Runs a lifecycle action and adopts the returned [Trip] as truth. Errors
  /// propagate to the caller (the screen shows a snackbar) without clobbering
  /// the on-screen trip with an [AsyncError].
  Future<Trip> _act(Future<Trip> Function(String tripId) call) async {
    final next = await call(_requireTripId());
    _syncStreaming(next);
    state = AsyncData(next);
    return next;
  }

  String _requireTripId() {
    final id = state.value?.publicId;
    if (id == null) {
      throw const AppFailure(
        code: 'INVALID_STATE',
        message: 'No active trip right now.',
      );
    }
    return id;
  }

  /// Starts or stops mirroring location samples to `trip.location`, matching
  /// whether a trip is currently active. The pump itself (online/offline) is
  /// owned by the home controller; this only forwards while a trip is live.
  void _syncStreaming(Trip? trip) {
    final active = trip != null && trip.status.isActive;
    if (active && _locSub == null) {
      final location = ref.read(liveLocationServiceProvider);
      _locSub = location.samples.listen(_emitLocation);
    } else if (!active && _locSub != null) {
      _locSub!.cancel();
      _locSub = null;
    }
  }

  void _emitLocation(LocationSample s) {
    final trip = state.value;
    if (trip == null || !trip.status.isActive) return;
    _socket.emit('trip.location', {
      'tripId': trip.publicId,
      'lat': s.lat,
      'lng': s.lng,
      if (s.speed != null) 'speed': s.speed,
      if (s.bearing != null) 'bearing': s.bearing,
    });
  }
}

final activeTripControllerProvider =
    AsyncNotifierProvider<ActiveTripController, Trip?>(
      ActiveTripController.new,
    );

/// Whether the driver currently has a live (non-terminal) trip — drives the
/// home "resume trip" banner and the searching shimmer.
final hasActiveTripProvider = Provider<bool>((ref) {
  final trip = ref.watch(activeTripControllerProvider).value;
  return trip != null && !trip.status.isTerminal;
});
