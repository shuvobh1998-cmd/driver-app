import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/scheduled_trip.dart';

/// A form row that captures a `{lat, lng}` by dropping a pin on a map, plus an
/// optional human address. Tapping opens a full-screen [_MapPickerPage].
class LocationPickerField extends StatelessWidget {
  const LocationPickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.point,
    required this.addressController,
    required this.onPicked,
    this.initialCenter,
  });

  final String label;
  final IconData icon;
  final LatLngPoint? point;
  final TextEditingController addressController;
  final ValueChanged<LatLngPoint> onPicked;

  /// Where the map opens when no point is chosen yet (e.g. the driver's spot).
  final LatLng? initialCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPoint = point != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(AppSpacing.radius),
            ),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        hasPoint
                            ? '${point!.lat.toStringAsFixed(5)}, ${point!.lng.toStringAsFixed(5)}'
                            : 'Tap to drop a pin on the map',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: hasPoint ? null : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasPoint ? Icons.edit_location_alt : Icons.map,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: '$label address (optional)',
          controller: addressController,
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final start = point != null
        ? LatLng(point!.lat, point!.lng)
        : (initialCenter ?? const LatLng(22.5726, 88.3639));
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _MapPickerPage(title: label, initial: start),
      ),
    );
    if (picked != null) {
      onPicked(LatLngPoint(lat: picked.latitude, lng: picked.longitude));
    }
  }
}

/// Full-screen map: pan to position the centre crosshair, then confirm.
class _MapPickerPage extends StatefulWidget {
  const _MapPickerPage({required this.title, required this.initial});

  final String title;
  final LatLng initial;

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  final MapController _controller = MapController();
  late LatLng _center = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pick ${widget.title.toLowerCase()}')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 15,
              onPositionChanged: (camera, _) =>
                  setState(() => _center = camera.center),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.driverapp.driver_app',
              ),
            ],
          ),
          // Fixed centre crosshair — the point that gets returned.
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.place, size: 44, color: AppColors.brand),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: PrimaryButton(
            label: 'Use this location',
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(_center),
          ),
        ),
      ),
    );
  }
}
