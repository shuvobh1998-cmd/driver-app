import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../../notifications/presentation/widgets/sos_dialog.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_enums.dart';
import '../controllers/active_trip_controller.dart';
import '../widgets/next_action_button.dart';
import '../widgets/otp_start_sheet.dart';
import '../widgets/trip_map.dart';
import '../widgets/trip_route_view.dart';

/// The active-trip screen: a map of the route, the trip's details, and the
/// single next action (Arrived → Start → End) derived from status. Cancelling
/// (pre-start) and reporting hide behind the overflow menu so the primary
/// action stays unambiguous.
class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  bool _busy = false;

  Future<void> _runAction(TripAction action, Trip trip) async {
    if (action == TripAction.start) {
      await showOtpStartSheet(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final controller = ref.read(activeTripControllerProvider.notifier);
      switch (action) {
        case TripAction.arrived:
          await controller.arrived();
        case TripAction.end:
          await controller.endTrip();
        case TripAction.start:
        case TripAction.none:
          break;
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Trip trip) async {
    final reason = await _askCancelReason();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(activeTripControllerProvider.notifier)
          .cancelTrip(reason: reason.isEmpty ? null : reason);
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel trip?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Rider not at pickup',
          ),
          maxLength: 280,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep trip'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(activeTripControllerProvider);

    // React to lifecycle outcomes: ended → summary, cancelled/gone → home.
    ref.listen(activeTripControllerProvider, (previous, next) {
      final trip = next.value;
      if (trip == null) {
        if (context.canPop()) context.pop();
        return;
      }
      if (trip.status == TripStatus.ended) {
        context.pushReplacement('/trip/${trip.publicId}/summary');
      } else if (trip.status == TripStatus.cancelled) {
        final who = trip.cancelledBy?.label ?? 'someone';
        context.showInfoSnack('Trip cancelled by $who.');
        ref.read(activeTripControllerProvider.notifier).clear();
        if (context.canPop()) context.pop();
      }
    });

    return tripAsync.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: ErrorState(
          message: messageForError(e),
          onRetry: () =>
              ref.read(activeTripControllerProvider.notifier).loadCurrent(),
        ),
      ),
      data: (trip) {
        if (trip == null || trip.status.isTerminal) {
          return const Scaffold(body: LoadingState());
        }
        return _buildActive(trip);
      },
    );
  }

  Widget _buildActive(Trip trip) {
    final action = TripAction.forStatus(trip.status);
    final canCancel =
        trip.status == TripStatus.accepted || trip.status == TripStatus.arrived;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current trip'),
        actions: [
          IconButton(
            tooltip: 'Share my ride',
            icon: const Icon(Icons.share_location),
            onPressed: () => context.push('/trips/${trip.publicId}/share'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'cancel') _cancel(trip);
            },
            itemBuilder: (context) => [
              if (canCancel)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel trip'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TripMap(pickup: trip.pickup, drop: trip.drop),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        StatusBadge(
                          label: trip.status.label,
                          tone: trip.status.tone,
                        ),
                        const Spacer(),
                        Text(
                          '${trip.paymentMethod.label} · ${formatPaise(trip.displayFare)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TripRouteView(pickup: trip.pickup, drop: trip.drop),
                    const SizedBox(height: AppSpacing.md),
                    NextActionButton(
                      action: action,
                      loading: _busy,
                      onPressed: () => _runAction(action, trip),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () =>
                          showSosSheet(context, ref, tripId: trip.publicId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(
                          AppSpacing.minTouchTarget,
                        ),
                      ),
                      icon: const Icon(Icons.emergency),
                      label: const Text('Emergency SOS'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
