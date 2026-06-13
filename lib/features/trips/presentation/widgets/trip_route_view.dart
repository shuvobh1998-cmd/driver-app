import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/trip.dart';

/// A pickup → drop pair shown as a connected timeline: a green dot for pickup,
/// a red pin for drop, joined by a dashed connector. Addresses fall back to
/// coordinates when the backend hasn't reverse-geocoded a place.
class TripRouteView extends StatelessWidget {
  const TripRouteView({super.key, required this.pickup, required this.drop});

  final TripPlace pickup;
  final TripPlace drop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Stop(
          icon: Icons.trip_origin,
          color: AppColors.success,
          label: 'Pickup',
          place: pickup,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 11),
          child: SizedBox(
            height: 24,
            child: VerticalDivider(width: 2, thickness: 2),
          ),
        ),
        _Stop(
          icon: Icons.location_on,
          color: AppColors.danger,
          label: 'Drop',
          place: drop,
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.color,
    required this.label,
    required this.place,
  });

  final IconData icon;
  final Color color;
  final String label;
  final TripPlace place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              Text(place.display, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
