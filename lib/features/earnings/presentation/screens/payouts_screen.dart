import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/models/payout.dart';
import '../controllers/payouts_controller.dart';

/// Payout history with the saved method shortcut up top and a "withdraw" CTA.
/// Tapping a payout opens its status detail.
class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
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
      ref.read(payoutsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payoutsControllerProvider);
    final controller = ref.read(payoutsControllerProvider.notifier);

    return AppScaffold(
      title: 'Payouts',
      padded: false,
      actions: [
        IconButton(
          tooltip: 'Payout method',
          icon: const Icon(Icons.settings),
          onPressed: () => context.push(Routes.payoutMethod),
        ),
      ],
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: controller.refresh,
        ),
        data: (state) {
          if (state.payouts.isEmpty) {
            return const EmptyState(
              icon: Icons.payments,
              title: 'No payouts yet',
              message: 'Your withdrawals will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: _scroll,
              padding: AppSpacing.screen,
              itemCount: state.payouts.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= state.payouts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _PayoutTile(payout: state.payouts[index]);
              },
            ),
          );
        },
      ),
      bottomBar: PrimaryButton(
        label: 'Withdraw',
        icon: Icons.account_balance,
        onPressed: () => context.push(Routes.requestPayout),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/payouts/${payout.id}'),
        leading: const CircleAvatar(child: Icon(Icons.north_east, size: 20)),
        title: Text(
          formatPaise(payout.amount),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(payout.requestedAt.toFriendly()),
        trailing: StatusBadge(
          label: payout.status.label,
          tone: payout.status.tone,
        ),
      ),
    );
  }
}
