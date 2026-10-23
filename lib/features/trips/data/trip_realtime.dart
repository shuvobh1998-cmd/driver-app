import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/websocket/driver_socket.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../driver_home/presentation/controllers/driver_home_controller.dart';
import '../presentation/controllers/active_trip_controller.dart';
import '../presentation/controllers/trip_offer_controller.dart';
import 'models/trip_offer.dart';

/// Owns the socket's lifecycle and fans the realtime trip events out to the
/// controllers that hold UI state.
///
/// - Connects on sign-in, disconnects on sign-out. The handshake reads the
///   current access token on every (re)connect.
/// - When the server cuts the connection (expired token), refreshes the token
///   and reconnects with a backoff — Socket.IO won't retry that by itself.
/// - `trip.offered` → [TripOfferController.present] (the offer gate then shows
///   the full-screen takeover).
/// - `trip.status.changed` / `trip.driver.arrived` / `trip.completed` /
///   `trip.cancelled` / `payment.succeeded` → [ActiveTripController.reconcile]
///   (REST is the truth).
/// - On every (re)connect → reconcile the active trip and the driver state,
///   since events may have been missed while the socket was down.
class TripRealtimeCoordinator {
  TripRealtimeCoordinator(this._ref, {Duration initialBackoff = _minBackoff})
    : _initialBackoff = initialBackoff,
      _backoff = initialBackoff;

  final Ref _ref;
  final Duration _initialBackoff;
  // Captured once at start so [dispose] never reads a provider in a lifecycle
  // callback (Riverpod forbids that).
  DriverSocket? _socket;
  ProviderSubscription<AuthState>? _authSub;
  bool _connected = false;
  bool _reconnecting = false;
  Duration _backoff;

  static const _minBackoff = Duration(seconds: 1);
  static const _maxBackoff = Duration(seconds: 60);

  static const _tripEvents = [
    'trip.status.changed',
    'trip.driver.arrived',
    'trip.completed',
    'trip.cancelled',
    'payment.succeeded',
  ];

  /// Registers the event handlers and begins watching auth, connecting and
  /// disconnecting accordingly.
  void start() {
    final socket = _ref.read(driverSocketProvider);
    _socket = socket;
    socket.on('trip.offered', _onOffered);
    for (final event in _tripEvents) {
      socket.on(event, _onTripEvent);
    }
    _authSub = _ref.listen<AuthState>(authControllerProvider, (_, next) {
      _onAuth(next);
    }, fireImmediately: true);
  }

  void dispose() {
    _authSub?.close();
    final socket = _socket;
    if (socket == null) return;
    socket.off('trip.offered', _onOffered);
    for (final event in _tripEvents) {
      socket.off(event, _onTripEvent);
    }
    socket.disconnect();
  }

  void _onAuth(AuthState auth) {
    // A profile edit re-emits an authenticated state; only the sign-in itself
    // opens a connection.
    if (auth.isAuthenticated) {
      if (!_connected) _connect();
    } else {
      _disconnect();
    }
  }

  void _connect() {
    final tokens = _ref.read(authTokenServiceProvider);
    final token = tokens.accessToken;
    if (token == null || token.isEmpty) return;

    _connected = true;
    _socket?.connect(
      accessToken: () => tokens.accessToken,
      onConnect: _onConnect,
      onServerDisconnect: _onServerDisconnect,
    );
  }

  void _disconnect() {
    if (!_connected) return;
    _connected = false;
    _socket?.disconnect();
    _ref.read(tripOfferControllerProvider.notifier).clear();
  }

  /// Reconcile on (re)connect — covers events missed while the socket was down.
  void _onConnect() {
    _backoff = _initialBackoff;
    _ref.read(activeTripControllerProvider.notifier).loadCurrent();
    if (_ref.exists(driverHomeControllerProvider)) {
      _ref.read(driverHomeControllerProvider.notifier).refresh().ignore();
    }
  }

  /// The server closed the socket — almost always an expired access token.
  /// Refresh it and reconnect, backing off so a persistent failure (server
  /// down, account suspended) doesn't spin.
  Future<void> _onServerDisconnect() async {
    if (_reconnecting) return;
    _reconnecting = true;
    try {
      await Future<void>.delayed(_backoff);
      final doubled = _backoff * 2;
      _backoff = doubled > _maxBackoff ? _maxBackoff : doubled;
      if (!_connected) return;

      final tokens = _ref.read(authTokenServiceProvider);
      try {
        if (!await tokens.refresh()) {
          tokens.forceSignOut();
          return;
        }
      } catch (_) {
        // Server unreachable — retry with the token we have.
      }
      if (_connected) _socket?.reconnect();
    } finally {
      _reconnecting = false;
    }
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
