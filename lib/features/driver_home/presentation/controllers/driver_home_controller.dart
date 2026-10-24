import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core_providers.dart';
import '../../../../core/location/live_location_service.dart';
import '../../data/driver_home_providers.dart';
import '../../data/driver_state_api.dart';
import '../../data/models/driver_state.dart';

/// Single source of truth for the driver's online/offline/on-trip state and the
/// location pump that feeds the admin live-map.
///
/// **WS is a notifier, REST is the truth:** every transition reconciles against
/// the [DriverState] the server returns. Pings flow every ~5s from
/// [LiveLocationService]. A ping lost to a network blip is not replayed: the
/// server matches on the latest position, so the next tick's fresher fix is
/// what it needs. A ping the server refuses (e.g. the driver was swept offline
/// after 90 s without one) triggers a state re-sync so the UI shows the truth.
class DriverHomeController extends AsyncNotifier<DriverState> {
  DriverStateApi get _api => ref.read(driverStateApiProvider);
  LiveLocationService get _location => ref.read(liveLocationServiceProvider);

  StreamSubscription<LocationSample>? _pumpSub;
  bool _reporting = false;

  @override
  Future<DriverState> build() async {
    // Capture the service now: a Ref can't be read inside an onDispose callback.
    final location = ref.read(liveLocationServiceProvider);
    ref.onDispose(() {
      _pumpSub?.cancel();
      location.stop();
    });

    final serverState = await _api.getState();
    // Survives a relaunch: if the server still has us online, resume streaming.
    // A location failure (permission revoked, GPS off) must not fail the build:
    // with no state the home screen falls back to "Offline" with a dead button.
    // The driver still sees the server truth and can go offline / back online,
    // which re-asks for permission.
    if (serverState.isOnline) {
      await _startPump().catchError((_) {});
    }
    return serverState;
  }

  /// Whether the location service is producing pings right now.
  bool get isStreaming => _location.isRunning;

  /// Goes online with [vehicleId]. Caller must have secured location permission
  /// first (the permission primer). Starts the pump on success. The previous
  /// [AsyncData] is kept while the request is in flight (so the map doesn't
  /// flicker); [driverTransitioningProvider] drives the button spinner.
  Future<void> goOnline(String vehicleId) async {
    final transition = ref.read(driverTransitioningProvider.notifier);
    transition.set(true);
    try {
      state = await AsyncValue.guard(() async {
        final next = await _api.goOnline(vehicleId);
        await _startPump();
        return next;
      });
    } finally {
      transition.set(false);
    }
  }

  /// Goes offline: stops the pump first so no ping races the transition, then
  /// reconciles with the server.
  Future<void> goOffline() async {
    final transition = ref.read(driverTransitioningProvider.notifier);
    transition.set(true);
    try {
      state = await AsyncValue.guard(() async {
        await _stopPump();
        return _api.goOffline();
      });
    } finally {
      transition.set(false);
    }
  }

  /// Re-fetches server state (e.g. after a socket reconnect) without disturbing
  /// the pump.
  Future<void> refresh() async {
    final next = await _api.getState();
    if (next.isOnline && !_location.isRunning) {
      await _startPump();
    } else if (!next.isOnline && _location.isRunning) {
      await _stopPump();
    }
    state = AsyncData(next);
  }

  Future<void> _startPump() async {
    if (_pumpSub != null) return;
    await _location.start();
    _pumpSub = _location.samples.listen(_onSample);
  }

  Future<void> _stopPump() async {
    await _pumpSub?.cancel();
    _pumpSub = null;
    await _location.stop();
  }

  Future<void> _onSample(LocationSample s) async {
    // Skip a tick if the previous POST is still in flight; the next sample
    // carries fresher data anyway.
    if (_reporting) return;
    _reporting = true;
    try {
      final next = await _api.reportLocation(
        lat: s.lat,
        lng: s.lng,
        speed: s.speed,
        bearing: s.bearing,
      );
      // Reconcile: a server-side change (e.g. ON_TRIP) lands here too.
      if (state.value?.status != next.status ||
          state.value?.location?.lat != next.location?.lat) {
        state = AsyncData(next);
      }
    } on DioException catch (e) {
      // No response = network blip: drop it, the next tick sends a fresh fix.
      // A response means the server refused the ping — usually because we're
      // no longer ONLINE — so re-sync (which stops the pump if we're offline).
      if (e.response != null) await refresh().catchError((_) {});
    } catch (_) {
      // Never let a ping failure escape the stream listener.
    } finally {
      _reporting = false;
    }
  }
}

final driverHomeControllerProvider =
    AsyncNotifierProvider<DriverHomeController, DriverState>(
      DriverHomeController.new,
    );

/// True while a go-online/offline transition is in flight. Kept separate from
/// the [DriverState] async value so the home map keeps showing the last known
/// position (no flicker) while only the button shows a spinner.
class DriverTransitioning extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final driverTransitioningProvider = NotifierProvider<DriverTransitioning, bool>(
  DriverTransitioning.new,
);
