import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// Thin wrapper over the Socket.IO connection to the backend gateway.
///
/// Per the **locked** realtime contract the gateway is mounted at the host root
/// (not under `/api/v1`, and not on a `/driver` namespace). The JWT **access
/// token** authenticates the handshake via `auth.token` — never an
/// `Authorization` header. It's read at every (re)connect, so reconnecting
/// after the 15-minute access token has rotated still authenticates.
///
/// On a successful handshake the server auto-joins `user:<id>`, so trip offers
/// (`trip.offered`) and lifecycle events arrive without any subscribe. Per-trip
/// rooms (`trip:<id>`) are opt-in via `trip.subscribe`.
///
/// Handlers registered with [on] are kept here and attached to every new
/// connection, so a feature can register before the first connect and keeps
/// its handler across a sign-out / sign-in.
///
/// Remember: **WS is a notifier, REST is the truth** — reconcile after reconnect.
class DriverSocket {
  DriverSocket(this._config);

  final AppConfig _config;
  io.Socket? _socket;
  final Map<String, List<void Function(dynamic data)>> _handlers = {};

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the connection, authenticating with whatever [accessToken] returns
  /// at handshake time. A second call disposes the previous socket first.
  /// [onConnect] fires on every (re)connect so callers can reconcile state.
  /// [onServerDisconnect] fires when the server cuts the connection (bad or
  /// expired token, suspended account): Socket.IO doesn't retry that on its
  /// own, so the caller refreshes the token and calls [reconnect].
  void connect({
    required String? Function() accessToken,
    void Function()? onConnect,
    void Function()? onServerDisconnect,
  }) {
    _socket?.dispose();
    final socket = io.io(
      _config.wsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuthFn((send) => send({'token': accessToken() ?? ''}))
          .build(),
    );
    _socket = socket;
    _handlers.forEach((event, handlers) {
      for (final handler in handlers) {
        socket.on(event, handler);
      }
    });
    if (onConnect != null) socket.onConnect((_) => onConnect());
    if (onServerDisconnect != null) {
      socket.onDisconnect((reason) {
        if (reason == 'io server disconnect') onServerDisconnect();
      });
    }
    socket.connect();
  }

  /// Re-opens a connection the server closed, with a freshly read token.
  void reconnect() => _socket?.connect();

  /// Subscribes to a server event. Feature controllers register their own event
  /// names; the wrapper stays event-agnostic.
  void on(String event, void Function(dynamic data) handler) {
    (_handlers[event] ??= []).add(handler);
    _socket?.on(event, handler);
  }

  /// Removes handlers for [event] (all of them when [handler] is omitted).
  void off(String event, [void Function(dynamic data)? handler]) {
    if (handler == null) {
      _handlers.remove(event);
    } else {
      _handlers[event]?.remove(handler);
    }
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
