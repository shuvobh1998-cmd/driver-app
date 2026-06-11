import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/phone.dart';
import '../../../../shared/utils/validators.dart';
import '../../data/auth_providers.dart';
import '../../data/models/gender.dart';
import '../../data/phone_verifier.dart';
import '../controllers/auth_controller.dart';

enum _Step { phone, otp, profile }

/// The 3-step signup flow (phone → OTP → profile), with the Firebase OTP step
/// in the middle. State is held in this one screen so tickets/tokens pass
/// between steps without route plumbing. The OTP step needs a configured
/// Firebase project; without it the verifier surfaces a clear message.
class SignupFlowScreen extends ConsumerStatefulWidget {
  const SignupFlowScreen({super.key});

  @override
  ConsumerState<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends ConsumerState<SignupFlowScreen> {
  _Step _step = _Step.phone;
  bool _busy = false;

  String _phoneE164 = '';
  String _signupTicket = '';
  String _signupToken = '';

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

  Future<void> _startPhone(String national) => _run(() async {
    final repo = ref.read(authRepositoryProvider);
    _phoneE164 = Phone.toE164(national);
    final res = await repo.signupStart(_phoneE164);
    _signupTicket = res.ticket;
    // Triggers the Firebase SMS. Throws on builds without Firebase wired in.
    await ref.read(phoneVerifierProvider).sendCode(_phoneE164);
    if (mounted) setState(() => _step = _Step.otp);
  });

  Future<void> _verifyOtp(String code) => _run(() async {
    final repo = ref.read(authRepositoryProvider);
    final idToken = await ref.read(phoneVerifierProvider).confirmCode(code);
    _signupToken = await repo.signupVerifyOtp(
      signupTicket: _signupTicket,
      firebaseIdToken: idToken,
    );
    if (mounted) setState(() => _step = _Step.profile);
  });

  Future<void> _completeProfile(_ProfileDraft draft) => _run(() async {
    await ref
        .read(authControllerProvider.notifier)
        .completeSignup(
          signupToken: _signupToken,
          firstName: draft.firstName,
          lastName: draft.lastName,
          email: draft.email,
          gender: draft.gender?.wireValue,
          password: draft.password,
          passwordConfirm: draft.passwordConfirm,
          emergencyContactName: draft.emergencyName,
          emergencyContactPhone: draft.emergencyPhone == null
              ? null
              : Phone.toE164(draft.emergencyPhone!),
        );
    // Authenticated → router redirects home.
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Create account',
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_step) {
          _Step.phone => _PhoneStep(
            busy: _busy,
            onSubmit: _startPhone,
            key: const ValueKey('phone'),
          ),
          _Step.otp => _OtpStep(
            busy: _busy,
            phone: _phoneE164,
            onSubmit: _verifyOtp,
            onResend: () => _run(
              () => ref.read(phoneVerifierProvider).sendCode(_phoneE164),
            ),
            key: const ValueKey('otp'),
          ),
          _Step.profile => _ProfileStep(
            busy: _busy,
            onSubmit: _completeProfile,
            key: const ValueKey('profile'),
          ),
        },
      ),
    );
  }
}

// ── Step 1: phone ──────────────────────────────────────────────────────────
class _PhoneStep extends StatefulWidget {
  const _PhoneStep({super.key, required this.busy, required this.onSubmit});
  final bool busy;
  final void Function(String national) onSubmit;

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text("What's your number?", style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "We'll text a verification code to confirm it's you.",
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
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Send code',
            loading: widget.busy,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                widget.onSubmit(_phone.text);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 2: OTP ────────────────────────────────────────────────────────────
class _OtpStep extends StatefulWidget {
  const _OtpStep({
    super.key,
    required this.busy,
    required this.phone,
    required this.onSubmit,
    required this.onResend,
  });
  final bool busy;
  final String phone;
  final void Function(String code) onSubmit;
  final VoidCallback onResend;

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Enter the code', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sent to ${Phone.pretty(widget.phone)}.',
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
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Verify',
            loading: widget.busy,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                widget.onSubmit(_code.text.trim());
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: widget.busy ? null : widget.onResend,
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: profile + password ─────────────────────────────────────────────
class _ProfileDraft {
  _ProfileDraft({
    required this.firstName,
    required this.password,
    required this.passwordConfirm,
    this.lastName,
    this.email,
    this.gender,
    this.emergencyName,
    this.emergencyPhone,
  });
  final String firstName;
  final String? lastName;
  final String? email;
  final Gender? gender;
  final String password;
  final String passwordConfirm;
  final String? emergencyName;
  final String? emergencyPhone;
}

class _ProfileStep extends StatefulWidget {
  const _ProfileStep({super.key, required this.busy, required this.onSubmit});
  final bool busy;
  final void Function(_ProfileDraft draft) onSubmit;

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emName = TextEditingController();
  final _emPhone = TextEditingController();
  Gender? _gender;

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _email,
      _password,
      _confirm,
      _emName,
      _emPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _emergencyPhoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    return Validators.phone(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Almost there', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set up your profile and a 6-digit PIN to log in with.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _first,
            label: 'First name',
            prefixIcon: Icons.person,
            validator: (v) => Validators.required(v, field: 'First name'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _last,
            label: 'Last name (optional)',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _email,
            label: 'Email (optional)',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<Gender>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender (optional)',
              prefixIcon: Icon(Icons.wc),
            ),
            items: const [
              DropdownMenuItem(value: Gender.male, child: Text('Male')),
              DropdownMenuItem(value: Gender.female, child: Text('Female')),
              DropdownMenuItem(value: Gender.other, child: Text('Other')),
              DropdownMenuItem(
                value: Gender.preferNotToSay,
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (g) => setState(() => _gender = g),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _password,
            label: 'Password (6-digit PIN)',
            prefixIcon: Icons.lock,
            obscureText: true,
            keyboardType: TextInputType.number,
            validator: Validators.pin6,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _confirm,
            label: 'Re-type PIN',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            keyboardType: TextInputType.number,
            validator: (v) => v != _password.text ? 'PINs do not match.' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Emergency contact (optional)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _emName,
            label: 'Contact name',
            prefixIcon: Icons.contact_emergency,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _emPhone,
            label: 'Contact phone',
            prefixIcon: Icons.phone_in_talk,
            keyboardType: TextInputType.phone,
            validator: _emergencyPhoneValidator,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Create account',
            loading: widget.busy,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                widget.onSubmit(
                  _ProfileDraft(
                    firstName: _first.text.trim(),
                    lastName: _last.text.trim().isEmpty
                        ? null
                        : _last.text.trim(),
                    email: _email.text.trim().isEmpty
                        ? null
                        : _email.text.trim(),
                    gender: _gender,
                    password: _password.text,
                    passwordConfirm: _confirm.text,
                    emergencyName: _emName.text.trim().isEmpty
                        ? null
                        : _emName.text.trim(),
                    emergencyPhone: _emPhone.text.trim().isEmpty
                        ? null
                        : _emPhone.text.trim(),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
