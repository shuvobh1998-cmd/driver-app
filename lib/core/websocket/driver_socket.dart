import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// Thin wrapper over the Socket.IO connection to the backend `/driver`
/// namespace. JWT travels in the connect query (never a header), per the
/// handoff conventions.
///
/// Skeleton: connect/disconnect lifecycle is in place; concrete event
/// subscriptions (`trip.*`, `chat.message.received`, …) land in their sprints.
/// Remember: **WS is a notifier, REST is the truth** — always reconcile.
class DriverSocket {
  DriverSocket(this._config);

  final AppConfig _config;
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the `/driver` namespace with the access token in the query.
  void connect(String accessToken) {
    _socket?.dispose();
    _socket = io.io(
      '${_config.wsBaseUrl}/driver',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setQuery({'token': accessToken})
          .build(),
    )..connect();
  }

  /// Subscribes to a server event. Feature controllers call this for their
  /// own event names; the wrapper stays event-agnostic.
  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
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
