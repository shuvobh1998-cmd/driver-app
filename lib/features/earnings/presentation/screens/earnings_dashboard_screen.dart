import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/earnings_providers.dart';
import '../../data/models/earnings_enums.dart';
import '../../data/models/earnings_summary.dart';
import '../widgets/earnings_bar_trend.dart';

/// The earnings dashboard: net + gross for today / this-week / this-month, trip
/// counts, a simple comparison bar, and shortcuts into the wallet and payouts.
class EarningsDashboardScreen extends ConsumerWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(earningsProvider(EarningsPeriod.today));
    final week = ref.watch(earningsProvider(EarningsPeriod.thisWeek));
    final month = ref.watch(earningsProvider(EarningsPeriod.thisMonth));

    Future<void> refresh() async {
      ref
        ..invalidate(earningsProvider(EarningsPeriod.today))
        ..invalidate(earningsProvider(EarningsPeriod.thisWeek))
        ..invalidate(earningsProvider(EarningsPeriod.thisMonth));
      await ref.read(earningsProvider(EarningsPeriod.today).future);
    }

    return AppScaffold(
      title: 'Earnings',
      padded: false,
      actions: [
        IconButton(
          tooltip: 'Wallet',
          icon: const Icon(Icons.account_balance_wallet),
          onPressed: () => context.push(Routes.wallet),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            _PeriodCard(period: EarningsPeriod.today, async: today),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MiniPeriodCard(
                    period: EarningsPeriod.thisWeek,
                    async: week,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MiniPeriodCard(
                    period: EarningsPeriod.thisMonth,
                    async: month,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _TrendCard(today: today, week: week, month: month),
            const SizedBox(height: AppSpacing.lg),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('Wallet & ledger'),
                    subtitle: const Text('Balance and every transaction'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.wallet),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.payments),
                    title: const Text('Payouts'),
                    subtitle: const Text('Withdrawals and payout method'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.payouts),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big card for the headline window (today): net front and centre, gross + trip
/// count beneath.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.period, required this.async});

  final EarningsPeriod period;
  final AsyncValue<EarningsSummary> async;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.brand,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: async.when(
          loading: () => const SizedBox(
            height: 96,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          error: (e, _) => SizedBox(
            height: 96,
            child: Center(
              child: Text(
                messageForError(e),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${period.label} · net',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatPaise(s.netEarning),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gross ${formatPaise(s.grossFare)} · ${s.tripsCount} '
                '${s.tripsCount == 1 ? 'trip' : 'trips'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact card for the secondary windows (week / month).
class _MiniPeriodCard extends StatelessWidget {
  const _MiniPeriodCard({required this.period, required this.async});

  final EarningsPeriod period;
  final AsyncValue<EarningsSummary> async;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: async.when(
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 72,
            child: Center(
              child: Text(
                messageForError(e),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(period.label, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatPaise(s.netEarning),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${s.tripsCount} ${s.tripsCount == 1 ? 'trip' : 'trips'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple bar comparison of net earnings across the three windows.
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.today,
    required this.week,
    required this.month,
  });

  final AsyncValue<EarningsSummary> today;
  final AsyncValue<EarningsSummary> week;
  final AsyncValue<EarningsSummary> month;

  @override
  Widget build(BuildContext context) {
    final bars = <EarningsBar>[
      if (today.hasValue)
        EarningsBar(label: 'Today', value: today.value!.netEarning),
      if (week.hasValue)
        EarningsBar(label: 'Week', value: week.value!.netEarning),
      if (month.hasValue)
        EarningsBar(label: 'Month', value: month.value!.netEarning),
    ];
    if (bars.length < 3) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net earnings', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            EarningsBarTrend(bars: bars),
          ],
        ),
      ),
    );
  }
}
