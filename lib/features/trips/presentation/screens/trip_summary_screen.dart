import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../../earnings/data/earnings_providers.dart';
import '../../../earnings/data/models/earnings_enums.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_enums.dart';
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
          if (trip.paymentMethod == PaymentMethod.cash) ...[
            const SizedBox(height: AppSpacing.md),
            _CashCollectCard(trip: trip),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('View invoice'),
              subtitle: const Text('Tax invoice and PDF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/trips/${trip.publicId}/invoice'),
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

/// On a finished CASH trip the driver has the rider's cash in hand, so the
/// platform's commission + GST must be settled from the wallet. This card runs
/// `POST /trips/:id/payment/cash-collected` (idempotent) and reflects the close.
class _CashCollectCard extends ConsumerStatefulWidget {
  const _CashCollectCard({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_CashCollectCard> createState() => _CashCollectCardState();
}

class _CashCollectCardState extends ConsumerState<_CashCollectCard> {
  bool _busy = false;
  bool _done = false;

  bool get _alreadyPaid => widget.trip.paymentStatus == PaymentStatus.paid;

  Future<void> _collect() async {
    setState(() => _busy = true);
    try {
      final payment = await ref
          .read(earningsApiProvider)
          .cashCollected(widget.trip.publicId);
      // Refresh the money surfaces the close affects.
      ref
        ..invalidate(walletProvider)
        ..invalidate(earningsProvider(EarningsPeriod.today))
        ..invalidate(tripDetailProvider(widget.trip.publicId));
      if (!mounted) return;
      setState(() => _done = true);
      context.showInfoSnack(
        'Cash collected. ${formatPaise(payment.platformCut)} settled from your '
        'wallet.',
      );
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_alreadyPaid || _done) {
      return Card(
        margin: EdgeInsets.zero,
        color: AppColors.success.withValues(alpha: 0.08),
        child: const ListTile(
          leading: Icon(Icons.check_circle, color: AppColors.success),
          title: Text('Cash settled'),
          subtitle: Text('Commission and GST debited from your wallet.'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Text('Cash trip', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Collect ${formatPaise(widget.trip.displayFare)} from the rider, '
              'then confirm so commission + GST settle from your wallet.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Cash collected',
              icon: Icons.check,
              loading: _busy,
              onPressed: _collect,
            ),
          ],
        ),
      ),
    );
  }
}
