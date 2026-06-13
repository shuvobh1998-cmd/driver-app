import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/earnings_providers.dart';
import '../../data/models/earnings_enums.dart';
import '../../data/models/payout_method.dart';

/// Add or edit the payout destination: a UPI id, or bank account + IFSC. Saving
/// stores it via `PUT /drivers/me/payout-method`.
class PayoutMethodScreen extends ConsumerStatefulWidget {
  const PayoutMethodScreen({super.key});

  @override
  ConsumerState<PayoutMethodScreen> createState() => _PayoutMethodScreenState();
}

class _PayoutMethodScreenState extends ConsumerState<PayoutMethodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upi = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();

  PayoutMethodType _type = PayoutMethodType.upi;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _upi.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  /// Seed the form from the existing method (once), so editing UPI keeps the id.
  /// The bank account number arrives masked, so it is left blank for re-entry.
  void _prefill(PayoutMethod? method) {
    if (_prefilled || method == null) return;
    _prefilled = true;
    _type = method.methodType == PayoutMethodType.unknown
        ? PayoutMethodType.upi
        : method.methodType;
    _upi.text = method.upiId ?? '';
    _accountName.text = method.accountName ?? '';
    _ifsc.text = method.ifsc ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = _type == PayoutMethodType.upi
          ? UpdatePayoutMethod.upi(upiId: _upi.text.trim())
          : UpdatePayoutMethod.bank(
              accountName: _accountName.text.trim(),
              accountNumber: _accountNumber.text.trim(),
              ifsc: _ifsc.text.trim().toUpperCase(),
            );
      await ref.read(earningsApiProvider).setPayoutMethod(body);
      ref.invalidate(payoutMethodProvider);
      if (!mounted) return;
      context.showInfoSnack('Payout method saved.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodAsync = ref.watch(payoutMethodProvider);
    methodAsync.whenData(_prefill);

    return AppScaffold(
      title: 'Payout method',
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            SegmentedButton<PayoutMethodType>(
              segments: const [
                ButtonSegment(
                  value: PayoutMethodType.upi,
                  label: Text('UPI'),
                  icon: Icon(Icons.qr_code),
                ),
                ButtonSegment(
                  value: PayoutMethodType.bank,
                  label: Text('Bank'),
                  icon: Icon(Icons.account_balance),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_type == PayoutMethodType.upi)
              AppTextField(
                controller: _upi,
                label: 'UPI ID',
                hint: 'name@bank',
                prefixIcon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your UPI ID';
                  if (!value.contains('@')) return 'Enter a valid UPI ID';
                  return null;
                },
              )
            else ...[
              AppTextField(
                controller: _accountName,
                label: 'Account holder name',
                prefixIcon: Icons.person,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter the name' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _accountNumber,
                label: 'Account number',
                prefixIcon: Icons.numbers,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.length < 6) return 'Enter the account number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _ifsc,
                label: 'IFSC code',
                prefixIcon: Icons.account_balance,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (v) {
                  final value = v?.trim().toUpperCase() ?? '';
                  if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value)) {
                    return 'Enter a valid IFSC';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      bottomBar: PrimaryButton(
        label: 'Save',
        loading: _saving,
        onPressed: _save,
      ),
    );
  }
}
