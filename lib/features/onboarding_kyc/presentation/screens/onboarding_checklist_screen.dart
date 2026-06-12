import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/kyc_status_summary.dart';
import '../../data/models/onboarding_enums.dart';
import '../../data/models/vehicle.dart';
import '../../data/onboarding_providers.dart';
import '../widgets/onboarding_stepper.dart';

/// The onboarding hub: a progress stepper (① Documents ② Vehicle ③ Review) and
/// a card per stage showing completion and linking into each flow.
class OnboardingChecklistScreen extends ConsumerWidget {
  const OnboardingChecklistScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(kycStatusProvider);
    ref.invalidate(vehiclesProvider);
    await Future.wait([
      ref.read(kycStatusProvider.future),
      ref.read(vehiclesProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kyc = ref.watch(kycStatusProvider);
    final vehicles = ref.watch(vehiclesProvider);

    return AppScaffold(
      title: 'Driver onboarding',
      padded: false,
      body: switch ((kyc, vehicles)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => ErrorState(
          message: messageForError(error),
          onRetry: () => _refresh(ref),
        ),
        (AsyncData(value: final k), AsyncData(value: final v)) => _Hub(
          kyc: k,
          vehicles: v,
          onRefresh: () => _refresh(ref),
        ),
        _ => const LoadingState(message: 'Loading your progress…'),
      },
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({
    required this.kyc,
    required this.vehicles,
    required this.onRefresh,
  });

  final KycStatusSummary kyc;
  final List<Vehicle> vehicles;
  final Future<void> Function() onRefresh;

  int get _requiredTotal =>
      kyc.requiredDocs.isEmpty ? 2 : kyc.requiredDocs.length;
  int get _requiredDone =>
      (_requiredTotal - kyc.missing.length).clamp(0, _requiredTotal);

  bool get _docsDone => kyc.allRequiredUploaded;
  bool get _vehicleDone => vehicles.isNotEmpty;
  bool get _approved =>
      kyc.status == KycStatus.approved &&
      vehicles.any((v) => v.status == VehicleStatus.active);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: AppSpacing.screen,
        children: [
          OnboardingStepper(
            steps: [
              OnboardingStep(label: 'Documents', done: _docsDone),
              OnboardingStep(label: 'Vehicle', done: _vehicleDone),
              OnboardingStep(label: 'Review', done: _approved),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _StageCard(
            icon: Icons.folder_copy_outlined,
            title: 'Documents',
            subtitle: _docsDone
                ? 'All required documents uploaded'
                : '$_requiredDone of $_requiredTotal required uploaded',
            done: _docsDone,
            onTap: () => context.push(Routes.kycDocuments),
          ),
          _StageCard(
            icon: Icons.directions_car_outlined,
            title: 'Vehicle',
            subtitle: _vehicleDone
                ? '${vehicles.length} vehicle(s) registered'
                : 'Register your vehicle and add a photo',
            done: _vehicleDone,
            onTap: () => context.push(Routes.vehicles),
          ),
          _StageCard(
            icon: Icons.verified_user_outlined,
            title: 'Review & approval',
            subtitle: _approved
                ? "You're approved — you can go online"
                : 'Track your approval status',
            done: _approved,
            onTap: () => context.push(Routes.approvalStatus),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: done
              ? AppColors.success.withValues(alpha: 0.15)
              : theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            done ? Icons.check : icon,
            color: done ? AppColors.success : theme.colorScheme.primary,
          ),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
