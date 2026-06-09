import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/config_providers.dart';
import 'location/live_location_service.dart';
import 'push/push_service.dart';
import 'storage/app_database.dart';
import 'storage/secure_token_store.dart';
import 'websocket/driver_socket.dart';

/// Process-wide singletons for the core services. Feature code depends on
/// these providers rather than constructing services directly.

final secureTokenStoreProvider = Provider<SecureTokenStore>(
  (ref) => SecureTokenStore(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final driverSocketProvider = Provider<DriverSocket>((ref) {
  final socket = DriverSocket(ref.watch(appConfigProvider));
  ref.onDispose(socket.disconnect);
  return socket;
});

final liveLocationServiceProvider = Provider<LiveLocationService>(
  (ref) => LiveLocationService(),
);

final pushServiceProvider = Provider<PushService>((ref) => PushService());
