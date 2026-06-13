import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/money.dart';
import '../../data/models/scheduled_trip.dart';

/// A posted carpool trip at a glance: route, departure, seats, price and status.
class ScheduledTripCard extends StatelessWidget {
  const ScheduledTripCard({super.key, required this.trip, this.onTap});

  final ScheduledTrip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.departureAt.toFriendly(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StatusBadge(label: trip.status.label, tone: trip.status.tone),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _RouteLine(icon: Icons.trip_origin, text: trip.originLabel),
              const SizedBox(height: AppSpacing.xs),
              _RouteLine(icon: Icons.place, text: trip.destLabel),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.event_seat,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${trip.availableSeats}/${trip.totalSeats} seats free',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${formatPaise(trip.pricePerSeat)}/seat',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
