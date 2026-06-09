import 'package:geolocator/geolocator.dart';

/// Streams the driver's location while they are online (~5s cadence), including
/// when backgrounded (a foreground service is configured in D3). Pings that
/// fail to upload are queued in [AppDatabase.LocationPings] and flushed on
/// reconnect.
///
/// Skeleton: exposes the permission check + a position stream; the timer loop,
/// background service and queue/flush land in D3.
class LiveLocationService {
  LiveLocationService();

  static const Duration pingInterval = Duration(seconds: 5);

  /// Ensures we hold (or can request) location permission before going online.
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Position updates at roughly [pingInterval] cadence.
  Stream<Position> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

  // TODO(D3): start()/stop() tied to DriverStateController; foreground
  // service notification; offline queue + flush on reconnect.
}
