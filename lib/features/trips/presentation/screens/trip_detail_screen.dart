import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_enums.dart';
import '../../data/trips_providers.dart';
import '../widgets/fare_breakdown_view.dart';
import '../widgets/report_problem_sheet.dart';
import '../widgets/trip_route_view.dart';
import '../widgets/trip_stats.dart';

/// Read-only detail for a past trip, with report-a-problem.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripDetailProvider(tripId));

    return AppScaffold(
      title: 'Trip detail',
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        ),
        data: (trip) => _Detail(trip: trip),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.trip});

  final Trip trip;

  Future<void> _report(BuildContext context) async {
    final filed = await showReportProblemSheet(context, trip.publicId);
    if (filed == true && context.mounted) {
      context.showInfoSnack('Thanks — we\'ll look into it.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Row(
          children: [
            StatusBadge(label: trip.status.label, tone: trip.status.tone),
            const Spacer(),
            Text(trip.createdAt.toFriendly(), style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TripStatsRow(trip: trip),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TripRouteView(pickup: trip.pickup, drop: trip.drop),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
        if (trip.status == TripStatus.cancelled && trip.cancelReason != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Card(
              color: AppColors.danger.withValues(alpha: 0.06),
              child: ListTile(
                leading: const Icon(Icons.cancel, color: AppColors.danger),
                title: Text('Cancelled by ${trip.cancelledBy?.label ?? '—'}'),
                subtitle: Text(trip.cancelReason!),
              ),
            ),
          ),
        if (trip.riderRating != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.star, color: AppColors.warning),
                title: Text('You rated this rider ${trip.riderRating}★'),
                subtitle: trip.riderRatingComment == null
                    ? null
                    : Text(trip.riderRatingComment!),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => _report(context),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Report a problem'),
        ),
      ],
    );
  }
}
