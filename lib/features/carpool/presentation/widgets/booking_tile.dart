import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/money.dart';
import '../../data/models/booking.dart';

/// A booking on the driver's carpool trip: rider, seats, fare, status, plus
/// chat and no-show actions.
class BookingTile extends StatelessWidget {
  const BookingTile({
    super.key,
    required this.booking,
    this.onChat,
    this.onNoShow,
  });

  final Booking booking;
  final VoidCallback? onChat;
  final VoidCallback? onNoShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rider = booking.rider;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      (rider?.avatarUrl != null && rider!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(rider.avatarUrl!)
                      : null,
                  child: (rider?.avatarUrl == null || rider!.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider?.name ?? 'Rider',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${booking.seats} seat(s) · ${formatPaise(booking.amount)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: booking.status.label,
                  tone: booking.status.tone,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.trip_origin,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    booking.pickupLabel,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (onChat != null || onNoShow != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onChat != null)
                    TextButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Chat'),
                    ),
                  if (onNoShow != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: onNoShow,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.person_off, size: 18),
                      label: const Text('No-show'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
