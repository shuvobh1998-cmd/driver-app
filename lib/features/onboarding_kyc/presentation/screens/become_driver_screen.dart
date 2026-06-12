import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/onboarding_providers.dart';

/// The "Become a driver" intro: what's needed, roughly how long it takes, and a
/// single CTA that upgrades the account to a driver, creates the driver profile
/// and drops the user into the onboarding hub.
class BecomeDriverScreen extends ConsumerStatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  ConsumerState<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends ConsumerState<BecomeDriverScreen> {
  bool _working = false;

  static const _checklist = [
    (Icons.badge_outlined, 'Aadhaar card', 'Photo or PDF, both sides clear'),
    (Icons.directions_car_outlined, 'Driving licence', 'Valid, not expired'),
    (
      Icons.two_wheeler_outlined,
      'Your vehicle',
      'Registration number + a clear photo',
    ),
  ];

  Future<void> _start() async {
    setState(() => _working = true);
    try {
      final api = ref.read(driverApiProvider);
      // Both calls are idempotent on the backend — safe if already a driver.
      await api.upgradeToDriver();
      await api.createProfile();
      await ref.read(authControllerProvider.notifier).refreshUser();
      ref.invalidate(driverProfileProvider);
      if (mounted) context.go(Routes.onboarding);
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Become a driver',
      bottomBar: PrimaryButton(
        label: 'Get started',
        icon: Icons.arrow_forward,
        loading: _working,
        onPressed: _start,
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Icon(Icons.local_taxi, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Start earning on your schedule',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Submitting your documents takes about 5 minutes. '
            'Approval is usually within 24 hours.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("What you'll need", style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, title, subtitle) in _checklist)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(title),
              subtitle: Text(subtitle),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
