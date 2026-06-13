import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// Thin wrapper over the Socket.IO connection to the backend gateway.
///
/// Per the **locked** realtime contract the gateway is mounted at the host root
/// (not under `/api/v1`, and not on a `/driver` namespace). The JWT **access
/// token** authenticates the handshake via `auth.token` (the preferred channel),
/// with the `token` query as a fallback — never an `Authorization` header.
///
/// On a successful handshake the server auto-joins `user:<id>`, so trip offers
/// (`trip.offered`) and lifecycle events arrive without any subscribe. Per-trip
/// rooms (`trip:<id>`) are opt-in via `trip.subscribe`.
///
/// Remember: **WS is a notifier, REST is the truth** — reconcile after reconnect.
class DriverSocket {
  DriverSocket(this._config);

  final AppConfig _config;
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the connection with [accessToken]. Idempotent for a given token: a
  /// second call disposes the previous socket first. [onConnect] fires on every
  /// (re)connect so callers can reconcile state; [onDisconnect] on every drop.
  void connect(
    String accessToken, {
    void Function()? onConnect,
    void Function()? onDisconnect,
  }) {
    _socket?.dispose();
    _socket = io.io(
      _config.wsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth({'token': accessToken})
          .setQuery({'token': accessToken})
          .build(),
    );
    if (onConnect != null) _socket!.onConnect((_) => onConnect());
    if (onDisconnect != null) _socket!.onDisconnect((_) => onDisconnect());
    _socket!.connect();
  }

  /// Subscribes to a server event. Feature controllers register their own event
  /// names; the wrapper stays event-agnostic.
  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  /// Removes handlers for [event] (all of them when [handler] is omitted).
  void off(String event, [void Function(dynamic data)? handler]) {
    _socket?.off(event, handler);
  }

  /// Publishes a client event (e.g. `trip.subscribe`, `trip.location`).
  void emit(String event, Object? data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
