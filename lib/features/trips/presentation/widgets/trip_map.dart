import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/trip.dart';

/// A light OSM map showing the trip's pickup (and optional drop) as markers,
/// auto-fitted to contain both. Context, not a control — interactions are off so
/// it never steals a swipe from the surrounding screen.
class TripMap extends StatelessWidget {
  const TripMap({super.key, required this.pickup, this.drop});

  final TripPlace pickup;
  final TripPlace? drop;

  @override
  Widget build(BuildContext context) {
    final pickupPoint = LatLng(pickup.lat, pickup.lng);
    final dropPoint = drop == null ? null : LatLng(drop!.lat, drop!.lng);

    return FlutterMap(
      options: MapOptions(
        initialCenter: pickupPoint,
        initialZoom: 14,
        initialCameraFit: dropPoint == null
            ? null
            : CameraFit.coordinates(
                coordinates: [pickupPoint, dropPoint],
                padding: const EdgeInsets.all(48),
              ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.driverapp.driver_app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: pickupPoint,
              width: 36,
              height: 36,
              child: const _Pin(
                color: AppColors.success,
                icon: Icons.trip_origin,
              ),
            ),
            if (dropPoint != null)
              Marker(
                point: dropPoint,
                width: 36,
                height: 36,
                child: const _Pin(
                  color: AppColors.danger,
                  icon: Icons.location_on,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
