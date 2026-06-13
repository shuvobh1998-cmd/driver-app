import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/earnings_providers.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/models/wallet.dart';
import '../controllers/ledger_controller.dart';

/// The wallet: balance + lifetime totals up top, the full paginated ledger
/// below, and a withdraw CTA.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(ledgerControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(walletProvider);
    await ref.read(ledgerControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final ledgerAsync = ref.watch(ledgerControllerProvider);

    return AppScaffold(
      title: 'Wallet',
      padded: false,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ledgerAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: messageForError(e),
            onRetry: () =>
                ref.read(ledgerControllerProvider.notifier).refresh(),
          ),
          data: (ledger) {
            final empty = ledger.entries.isEmpty;
            // Header card + "Transactions" label, then either an empty notice or
            // the entries (plus a trailing spinner while more are loading).
            final rowCount = empty
                ? 1
                : ledger.entries.length + (ledger.hasMore ? 1 : 0);
            return ListView.separated(
              controller: _scroll,
              padding: AppSpacing.screen,
              itemCount: 2 + rowCount,
              separatorBuilder: (_, index) => index <= 1 || empty
                  ? const SizedBox.shrink()
                  : const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _BalanceCard(async: walletAsync),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  );
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  );
                }
                if (empty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: Text('No transactions yet.')),
                  );
                }
                final i = index - 2;
                if (i >= ledger.entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _LedgerTile(entry: ledger.entries[i]);
              },
            );
          },
        ),
      ),
      bottomBar: PrimaryButton(
        label: 'Withdraw',
        icon: Icons.account_balance,
        onPressed: () => context.push(Routes.requestPayout),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.async});

  final AsyncValue<Wallet> async;

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
            height: 88,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          error: (e, _) => SizedBox(
            height: 88,
            child: Center(
              child: Text(
                messageForError(e),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (w) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatPaise(w.balance),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Total(label: 'Earned', value: w.totalEarned),
                  _Total(label: 'Paid out', value: w.totalPaidOut),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        Text(
          formatPaise(value),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = entry.direction.isCredit;
    final color = credit ? AppColors.success : AppColors.danger;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          credit ? Icons.south_west : Icons.north_east,
          color: color,
          size: 20,
        ),
      ),
      title: Text(entry.note ?? entry.reason.label),
      subtitle: Text(entry.createdAt.toFriendly()),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${entry.direction.sign}${formatPaise(entry.amount)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            formatPaise(entry.balanceAfter),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
