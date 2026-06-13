import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/websocket/driver_socket.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../presentation/controllers/active_trip_controller.dart';
import '../presentation/controllers/trip_offer_controller.dart';
import 'models/trip_offer.dart';

/// Owns the socket's lifecycle and fans the realtime trip events out to the
/// controllers that hold UI state.
///
/// - Connects on sign-in (with the in-memory access token), disconnects on
///   sign-out.
/// - `trip.offered` → [TripOfferController.present] (the offer gate then shows
///   the full-screen takeover).
/// - `trip.status.changed` / `trip.driver.arrived` / `trip.completed` /
///   `trip.cancelled` → [ActiveTripController.reconcile] (REST is the truth).
/// - On every (re)connect → reconcile the active trip, since events may have
///   been missed while the socket was down.
class TripRealtimeCoordinator {
  TripRealtimeCoordinator(this._ref);

  final Ref _ref;
  // Captured once at start so [dispose] never reads a provider in a lifecycle
  // callback (Riverpod forbids that).
  DriverSocket? _socket;
  ProviderSubscription<AuthState>? _authSub;
  bool _connected = false;

  /// Begins watching auth and connects/disconnects accordingly.
  void start() {
    _socket = _ref.read(driverSocketProvider);
    _authSub = _ref.listen<AuthState>(authControllerProvider, (_, next) {
      _onAuth(next);
    }, fireImmediately: true);
  }

  void dispose() {
    _authSub?.close();
    _socket?.disconnect();
  }

  void _onAuth(AuthState auth) {
    if (auth.isAuthenticated) {
      _connect();
    } else {
      _disconnect();
    }
  }

  void _connect() {
    final token = _ref.read(authTokenServiceProvider).accessToken;
    if (token == null || token.isEmpty) return;

    final socket = _ref.read(driverSocketProvider);
    _socket = socket;
    socket.connect(token, onConnect: _onConnect);

    socket.on('trip.offered', _onOffered);
    socket.on('trip.status.changed', _onTripEvent);
    socket.on('trip.driver.arrived', _onTripEvent);
    socket.on('trip.completed', _onTripEvent);
    socket.on('trip.cancelled', _onTripEvent);
    _connected = true;
  }

  void _disconnect() {
    if (!_connected) return;
    _connected = false;
    _socket?.disconnect();
    _ref.read(tripOfferControllerProvider.notifier).clear();
  }

  /// Reconcile on (re)connect — covers events missed while the socket was down.
  void _onConnect() {
    _ref.read(activeTripControllerProvider.notifier).loadCurrent();
  }

  void _onOffered(dynamic data) {
    final offer = TripOffer.tryParse(data);
    if (offer == null || offer.isExpired) return;
    _ref.read(tripOfferControllerProvider.notifier).present(offer);
  }

  void _onTripEvent(dynamic data) {
    final tripId = data is Map ? data['tripId'] : null;
    if (tripId is! String || tripId.isEmpty) {
      _ref.read(activeTripControllerProvider.notifier).loadCurrent();
      return;
    }
    _ref.read(activeTripControllerProvider.notifier).reconcile(tripId);
  }
}

/// Always-alive coordinator. Mounted by the trip-offer gate at the app root so
/// the socket connects as soon as the app is running and authenticated.
final tripRealtimeCoordinatorProvider = Provider<TripRealtimeCoordinator>((
  ref,
) {
  final coordinator = TripRealtimeCoordinator(ref)..start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
