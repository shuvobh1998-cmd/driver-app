import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../design_system/design_system.dart';

/// The home map: OSM tiles centered on the driver with a single self-marker.
/// Kept deliberately light — the map is context, not the primary control.
class DriverMap extends StatefulWidget {
  const DriverMap({super.key, required this.center, this.online = false});

  /// The driver's position; the map re-centers when it changes.
  final LatLng center;
  final bool online;

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _controller.move(widget.center, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.online
        ? AppColors.brand
        : Theme.of(context).colorScheme.outline;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: 15,
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
              point: widget.center,
              width: 44,
              height: 44,
              child: _SelfMarker(color: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelfMarker extends StatelessWidget {
  const _SelfMarker({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}
