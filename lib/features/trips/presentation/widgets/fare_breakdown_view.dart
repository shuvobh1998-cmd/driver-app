import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/money.dart';
import '../../data/models/trip.dart';

/// Itemised fare, every line rendered from integer paise via [formatPaise].
/// Falls back to a single "Total fare" row when the backend hasn't attached a
/// breakdown (e.g. an estimate before the trip ends).
class FareBreakdownView extends StatelessWidget {
  const FareBreakdownView({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final b = trip.fareBreakdown;
    if (b == null) {
      return _Row(
        label: 'Total fare',
        value: formatPaise(trip.displayFare),
        emphasised: true,
      );
    }
    return Column(
      children: [
        _Row(label: 'Base fare', value: formatPaise(b.baseFare)),
        _Row(label: 'Distance', value: formatPaise(b.distanceFare)),
        _Row(label: 'Time', value: formatPaise(b.timeFare)),
        _Row(label: 'Platform fee', value: formatPaise(b.platformFee)),
        _Row(label: 'GST', value: formatPaise(b.gst)),
        const Divider(height: AppSpacing.lg),
        _Row(
          label: 'Total fare',
          value: formatPaise(b.total),
          emphasised: true,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasised
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
