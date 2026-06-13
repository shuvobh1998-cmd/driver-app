import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/earnings_providers.dart';
import '../../data/models/payout_method.dart';
import '../controllers/payouts_controller.dart';

/// Request a withdrawal: pick an amount (≤ balance), confirm against the saved
/// payout method. `INSUFFICIENT_BALANCE` / `PAYOUT_METHOD_REQUIRED` surface as
/// friendly copy.
class RequestPayoutScreen extends ConsumerStatefulWidget {
  const RequestPayoutScreen({super.key});

  @override
  ConsumerState<RequestPayoutScreen> createState() =>
      _RequestPayoutScreenState();
}

class _RequestPayoutScreenState extends ConsumerState<RequestPayoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _balancePaise => ref.read(walletProvider).value?.balance ?? 0;

  Future<void> _submit(PayoutMethod? method) async {
    if (method == null) {
      context.showInfoSnack('Add a payout method before withdrawing.');
      unawaited(context.push(Routes.payoutMethod));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final rupees = double.parse(_amount.text.trim());
    final paise = (rupees * 100).round();
    setState(() => _submitting = true);
    try {
      await ref.read(earningsApiProvider).requestPayout(amount: paise);
      ref.invalidate(walletProvider);
      await ref.read(payoutsControllerProvider.notifier).refresh();
      if (!mounted) return;
      context.showInfoSnack('Withdrawal requested.');
      context.pop();
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final methodAsync = ref.watch(payoutMethodProvider);
    final balance = walletAsync.value?.balance ?? 0;
    final method = methodAsync.value;

    return AppScaffold(
      title: 'Withdraw',
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Available balance'),
                trailing: Text(
                  formatPaise(balance),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PayoutMethodTile(async: methodAsync),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _amount,
              label: 'Amount (₹)',
              prefixText: '₹ ',
              prefixIcon: Icons.currency_rupee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (v) {
                final value = double.tryParse(v?.trim() ?? '');
                if (value == null || value <= 0) return 'Enter an amount';
                if ((value * 100).round() > _balancePaise) {
                  return 'Amount exceeds your balance';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final p in _quickAmounts(balance))
                  ActionChip(
                    label: Text(formatPaise(p, showDecimals: false)),
                    onPressed: () => _amount.text = (p ~/ 100).toString(),
                  ),
                if (balance > 0)
                  ActionChip(
                    label: const Text('All'),
                    onPressed: () =>
                        _amount.text = (balance / 100).toStringAsFixed(2),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomBar: PrimaryButton(
        label: 'Request withdrawal',
        loading: _submitting,
        onPressed: balance <= 0 ? null : () => _submit(method),
      ),
    );
  }

  /// Round-number quick picks that fit within the balance.
  List<int> _quickAmounts(int balance) =>
      [50000, 100000, 200000].where((p) => p <= balance).toList();
}

class _PayoutMethodTile extends StatelessWidget {
  const _PayoutMethodTile({required this.async});

  final AsyncValue<PayoutMethod?> async;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.payments),
          title: Text('Loading payout method…'),
        ),
      ),
      error: (_, _) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.payments),
          title: const Text('Add a payout method'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.payoutMethod),
        ),
      ),
      data: (method) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.payments),
          title: Text(method == null ? 'Add a payout method' : method.display),
          subtitle: method == null
              ? const Text('Required before withdrawing')
              : Text(method.methodType.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.payoutMethod),
        ),
      ),
    );
  }
}
