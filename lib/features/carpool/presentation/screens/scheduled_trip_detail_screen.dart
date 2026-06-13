import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/carpool_providers.dart';
import '../../data/models/booking.dart';
import '../../data/models/scheduled_trip.dart';
import '../controllers/my_trips_controller.dart';
import '../widgets/booking_tile.dart';

/// Detail for one posted carpool trip: summary, lifecycle actions (start /
/// complete / cancel / edit) and the list of bookings made on it.
class ScheduledTripDetailScreen extends ConsumerWidget {
  const ScheduledTripDetailScreen({super.key, required this.tripId});

  final String tripId;

  void _invalidate(WidgetRef ref) {
    ref.invalidate(scheduledTripDetailProvider(tripId));
    ref.invalidate(tripBookingsProvider(tripId));
    // The list screen reflects the new status on return.
    ref.read(myTripsControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(scheduledTripDetailProvider(tripId));

    return AppScaffold(
      title: 'Trip detail',
      padded: false,
      body: tripAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(scheduledTripDetailProvider(tripId)),
        ),
        data: (trip) => RefreshIndicator(
          onRefresh: () async => _invalidate(ref),
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              _Summary(trip: trip),
              const SizedBox(height: AppSpacing.md),
              _Actions(trip: trip, onChanged: () => _invalidate(ref)),
              const SizedBox(height: AppSpacing.lg),
              Text('Bookings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _Bookings(tripId: tripId, onChanged: () => _invalidate(ref)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.trip});

  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                StatusBadge(label: trip.status.label, tone: trip.status.tone),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _Line(icon: Icons.trip_origin, text: trip.originLabel),
            const SizedBox(height: AppSpacing.xs),
            _Line(icon: Icons.place, text: trip.destLabel),
            const Divider(height: AppSpacing.lg),
            _Line(icon: Icons.directions_car, text: trip.vehicle.display),
            const SizedBox(height: AppSpacing.xs),
            _Line(
              icon: Icons.event_seat,
              text:
                  '${trip.bookedSeats} booked · ${trip.availableSeats} free of ${trip.totalSeats}',
            ),
            const SizedBox(height: AppSpacing.xs),
            _Line(
              icon: Icons.payments,
              text: '${formatPaise(trip.pricePerSeat)} per seat',
            ),
            if (trip.preferences.ac == true ||
                (trip.preferences.gender != null)) ...[
              const SizedBox(height: AppSpacing.xs),
              _Line(
                icon: Icons.tune,
                text: [
                  if (trip.preferences.ac == true) 'AC',
                  if (trip.preferences.gender != null)
                    trip.preferences.gender!.label,
                ].join(' · '),
              ),
            ],
            if (trip.notes != null && trip.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _Line(icon: Icons.sticky_note_2, text: trip.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

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
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.trip, required this.onChanged});

  final ScheduledTrip trip;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged();
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() =>
      _run(() => ref.read(carpoolApiProvider).start(widget.trip.id));

  Future<void> _complete() =>
      _run(() => ref.read(carpoolApiProvider).complete(widget.trip.id));

  Future<void> _cancel() async {
    final reason = await _askReason(context);
    if (reason == null) return;
    await _run(
      () => ref
          .read(carpoolApiProvider)
          .cancel(widget.trip.id, reason: reason.isEmpty ? null : reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    if (trip.status.isTerminal) return const SizedBox.shrink();

    return Column(
      children: [
        if (trip.status.canStart)
          PrimaryButton(
            label: 'Start trip',
            icon: Icons.play_arrow,
            loading: _busy,
            onPressed: _busy ? null : _start,
          ),
        if (trip.status.isInProgress)
          PrimaryButton(
            label: 'Complete trip',
            icon: Icons.flag,
            loading: _busy,
            onPressed: _busy ? null : _complete,
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (trip.isEditable)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => context.push('/carpool/${trip.id}/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
            if (trip.isEditable) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<String?> _askReason(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'All bookings are refunded 100% and riders are notified.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: controller, label: 'Reason (optional)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep trip'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }
}

class _Bookings extends ConsumerWidget {
  const _Bookings({required this.tripId, required this.onChanged});

  final String tripId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripBookingsProvider(tripId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        message: messageForError(e),
        onRetry: () => ref.invalidate(tripBookingsProvider(tripId)),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: EmptyState(
              icon: Icons.people_outline,
              title: 'No bookings yet',
              message: 'Seats riders book will show up here.',
            ),
          );
        }
        return Column(
          children: [
            for (final b in bookings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: BookingTile(
                  booking: b,
                  onChat: b.rider == null
                      ? null
                      : () => context.push(
                          '/chats/${b.rider!.id}',
                          extra: b.rider!.name,
                        ),
                  onNoShow: b.status.canMarkNoShow
                      ? () => _markNoShow(context, ref, b)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _markNoShow(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as no-show?'),
        content: Text(
          'Mark ${booking.rider?.name ?? 'this rider'} as a no-show? '
          'This frees their seat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark no-show'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(carpoolApiProvider).markNoShow(booking.id);
      onChanged();
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }
}
