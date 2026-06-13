import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/phone.dart';
import '../../../../shared/utils/validators.dart';
import '../../data/auth_providers.dart';
import '../../data/phone_verifier.dart';
import '../controllers/auth_controller.dart';

enum _Step { phone, reset }

/// Reset password via OTP: enter phone → Firebase verifies it → set a new PIN.
/// On success a fresh session is issued and the router sends the driver home.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.phone;
  bool _busy = false;
  String _phoneE164 = '';
  String _resetTicket = '';

  @override
  void dispose() {
    for (final c in [_phone, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _requestReset() {
    if (!_phoneForm.currentState!.validate()) return;
    _run(() async {
      final repo = ref.read(authRepositoryProvider);
      _phoneE164 = Phone.toE164(_phone.text);
      _resetTicket = await repo.forgotRequest(_phoneE164);
      await ref.read(phoneVerifierProvider).sendCode(_phoneE164);
      if (mounted) setState(() => _step = _Step.reset);
    });
  }

  void _confirmReset() {
    if (!_resetForm.currentState!.validate()) return;
    _run(() async {
      final idToken = await ref
          .read(phoneVerifierProvider)
          .confirmCode(_code.text.trim());
      await ref
          .read(authControllerProvider.notifier)
          .resetPasswordWithOtp(
            resetTicket: _resetTicket,
            firebaseIdToken: idToken,
            newPassword: _password.text,
            newPasswordConfirm: _confirm.text,
          );
      // Authenticated → router redirects home.
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.resetTitle,
      body: _step == _Step.phone
          ? Form(
              key: _phoneForm,
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.forgotPinTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.forgotPinSubtitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PhoneNumberField(
                    controller: _phone,
                    label: l10n.phoneNumber,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: l10n.sendCode,
                    loading: _busy,
                    onPressed: _requestReset,
                  ),
                ],
              ),
            )
          : Form(
              key: _resetForm,
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.setNewPinTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.codeSentTo(Phone.pretty(_phoneE164)),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _code,
                    label: l10n.sixDigitCode,
                    prefixIcon: Icons.sms,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.otp(v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _password,
                    label: l10n.newPasswordPinLabel,
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    validator: Validators.pin6,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _confirm,
                    label: l10n.retypeNewPin,
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v != _password.text ? l10n.pinsDoNotMatch : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: l10n.resetPasswordButton,
                    loading: _busy,
                    onPressed: _confirmReset,
                  ),
                ],
              ),
            ),
    );
  }
}
