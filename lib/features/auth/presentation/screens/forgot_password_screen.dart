import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
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
    return AppScaffold(
      title: 'Reset password',
      body: _step == _Step.phone
          ? Form(
              key: _phoneForm,
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Forgot your PIN?',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Enter your number and we'll text a code to reset it.",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PhoneNumberField(
                    controller: _phone,
                    label: 'Phone number',
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Send code',
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
                  Text('Set a new PIN', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Code sent to ${Phone.pretty(_phoneE164)}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _code,
                    label: '6-digit code',
                    prefixIcon: Icons.sms,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.otp(v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _password,
                    label: 'New password (6-digit PIN)',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    validator: Validators.pin6,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _confirm,
                    label: 'Re-type new PIN',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v != _password.text ? 'PINs do not match.' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Reset password',
                    loading: _busy,
                    onPressed: _confirmReset,
                  ),
                ],
              ),
            ),
    );
  }
}
