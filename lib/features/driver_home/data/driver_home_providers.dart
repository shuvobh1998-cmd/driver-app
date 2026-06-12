import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/core_providers.dart';
import '../../../core/network/network_providers.dart';
import 'driver_state_api.dart';
import 'location_ping_store.dart';

final driverStateApiProvider = Provider<DriverStateApi>(
  (ref) => DriverStateApi(ref.watch(apiClientProvider).dio),
);

final locationPingStoreProvider = Provider<LocationPingStore>(
  (ref) => LocationPingStore(ref.watch(appDatabaseProvider)),
);

/// Where to first center the home map: the last known device fix if we have
/// one, otherwise a sensible city default (Kolkata) so the map never opens on
/// the ocean. The live self-marker takes over once pings start.
final initialMapCenterProvider = FutureProvider<LatLng>((ref) async {
  const fallback = LatLng(22.5726, 88.3639);
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LatLng(last.latitude, last.longitude);
    if (await Geolocator.checkPermission() == LocationPermission.always ||
        await Geolocator.checkPermission() == LocationPermission.whileInUse) {
      final pos = await Geolocator.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    }
  } catch (_) {
    // Fall through to the default on any permission/service error.
  }
  return fallback;
});
