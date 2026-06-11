import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/phone.dart';
import '../../../../shared/utils/validators.dart';
import '../controllers/auth_controller.dart';

/// Daily login: phone + 6-digit password, one call, no OTP. The router sends
/// the driver home as soon as [AuthController.login] flips the session.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(phone: Phone.toE164(_phone.text), password: _password.text);
      // On success the router redirect handles navigation.
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(Icons.local_taxi, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Welcome back', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign in to start driving.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _phone,
              label: 'Phone number',
              hint: '10-digit mobile',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _password,
              label: 'Password (6-digit PIN)',
              prefixIcon: Icons.lock,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              // Login only checks the field is present — the backend is the
              // authority on the password. (Setting a password still enforces
              // the 6-digit PIN rule in signup/reset.)
              validator: (v) => Validators.required(v, field: 'Password'),
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => context.push(Routes.forgot),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Log in',
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New here?'),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.push(Routes.signup),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
