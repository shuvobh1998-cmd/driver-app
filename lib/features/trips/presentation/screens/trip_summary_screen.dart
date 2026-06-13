import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/trip.dart';
import '../../data/trips_providers.dart';
import '../controllers/active_trip_controller.dart';
import '../widgets/fare_breakdown_view.dart';
import '../widgets/trip_stats.dart';

/// Post-trip summary: the fare breakdown, distance/time, payment method, and a
/// prompt to rate the rider. "Done" clears the finished trip and returns home.
class TripSummaryScreen extends ConsumerWidget {
  const TripSummaryScreen({super.key, required this.tripId});

  final String tripId;

  void _done(BuildContext context, WidgetRef ref) {
    ref.read(activeTripControllerProvider.notifier).clear();
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the trip already in hand (just ended); otherwise fetch it.
    final active = ref.watch(activeTripControllerProvider).value;
    if (active != null && active.publicId == tripId) {
      return _SummaryBody(trip: active, onDone: () => _done(context, ref));
    }
    final detail = ref.watch(tripDetailProvider(tripId));
    return detail.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Trip summary')),
        body: ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        ),
      ),
      data: (trip) =>
          _SummaryBody(trip: trip, onDone: () => _done(context, ref)),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.trip, required this.onDone});

  final Trip trip;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Trip summary',
      body: ListView(
        children: [
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 56,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Trip completed', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TripStatsRow(trip: trip),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Fare', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      StatusBadge(
                        label: trip.paymentMethod.label,
                        tone: StatusTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FareBreakdownView(trip: trip),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (trip.isRated)
            Card(
              color: AppColors.success.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.star, color: AppColors.success),
                title: Text('You rated this rider ${trip.riderRating}★'),
              ),
            )
          else
            PrimaryButton(
              label: 'Rate rider',
              icon: Icons.star,
              onPressed: () => context.push('/trip/${trip.publicId}/rate'),
            ),
        ],
      ),
      bottomBar: OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: onDone,
        child: const Text('Done'),
      ),
    );
  }
}
