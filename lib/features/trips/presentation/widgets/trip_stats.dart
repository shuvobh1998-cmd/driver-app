import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/money.dart';
import '../../data/models/trip.dart';

/// A row of three glanceable trip stats — distance, duration and fare — used on
/// the summary and detail screens. Distance/duration fall back to an em dash
/// until the backend has measured them (set on end).
class TripStatsRow extends StatelessWidget {
  const TripStatsRow({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(
          icon: Icons.straighten,
          label: 'Distance',
          value: _distance(trip.actualDistance),
        ),
        _Stat(
          icon: Icons.schedule,
          label: 'Duration',
          value: _duration(trip.actualDuration),
        ),
        _Stat(
          icon: Icons.payments,
          label: 'Fare',
          value: formatPaise(trip.displayFare),
        ),
      ],
    );
  }

  static String _distance(int? meters) {
    if (meters == null) return '—';
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
  }

  static String _duration(int? seconds) {
    if (seconds == null) return '—';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
