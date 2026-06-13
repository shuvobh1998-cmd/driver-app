import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/earnings_providers.dart';
import '../../data/models/payout.dart';

/// A single payout's status timeline + details.
class PayoutDetailScreen extends ConsumerWidget {
  const PayoutDetailScreen({super.key, required this.payoutId});

  final String payoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payoutProvider(payoutId));
    return AppScaffold(
      title: 'Payout',
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(payoutProvider(payoutId)),
        ),
        data: (payout) => _Detail(payout: payout),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Center(
          child: Column(
            children: [
              Text(
                formatPaise(payout.amount),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              StatusBadge(label: payout.status.label, tone: payout.status.tone),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(label: 'Method', value: payout.methodType.label),
              if (payout.upiId != null)
                _Row(label: 'UPI ID', value: payout.upiId!),
              _Row(label: 'Requested', value: payout.requestedAt.toFriendly()),
              if (payout.processedAt != null)
                _Row(
                  label: 'Processed',
                  value: payout.processedAt!.toFriendly(),
                ),
              if (payout.reference != null)
                _Row(label: 'Reference', value: payout.reference!),
              if (payout.notes != null)
                _Row(label: 'Notes', value: payout.notes!),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
