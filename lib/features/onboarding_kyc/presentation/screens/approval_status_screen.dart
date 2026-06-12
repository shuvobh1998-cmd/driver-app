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
import '../widgets/kyc_status_badge.dart';

/// The approval status screen: the overall KYC badge, exactly what is blocking
/// the driver from going online, and a "what happens next" explainer. A
/// rejection shows the reason with a one-tap path back to re-upload.
class ApprovalStatusScreen extends ConsumerWidget {
  const ApprovalStatusScreen({super.key});

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
      title: 'Approval status',
      body: switch ((kyc, vehicles)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => ErrorState(
          message: messageForError(error),
          onRetry: () => _refresh(ref),
        ),
        (AsyncData(value: final k), AsyncData(value: final v)) => _Status(
          kyc: k,
          vehicles: v,
          onRefresh: () => _refresh(ref),
        ),
        _ => const LoadingState(message: 'Checking your status…'),
      },
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.kyc,
    required this.vehicles,
    required this.onRefresh,
  });

  final KycStatusSummary kyc;
  final List<Vehicle> vehicles;
  final Future<void> Function() onRefresh;

  bool get _hasActiveVehicle =>
      vehicles.any((v) => v.status == VehicleStatus.active);
  bool get _canGoOnline =>
      kyc.status == KycStatus.approved && _hasActiveVehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(child: KycStatusBadge(status: kyc.status)),
          const SizedBox(height: AppSpacing.md),
          Text(
            _headline,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (kyc.status == KycStatus.rejected &&
              kyc.rejectedReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              kyc.rejectedReason!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Before you can go online', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _Requirement(
            label: 'Documents approved',
            met: kyc.status == KycStatus.approved,
          ),
          _Requirement(label: 'A vehicle approved', met: _hasActiveVehicle),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What happens next', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_nextSteps, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (kyc.status == KycStatus.rejected)
            PrimaryButton(
              label: 'Re-upload documents',
              icon: Icons.upload_file,
              onPressed: () => context.push(Routes.kycDocuments),
            )
          else if (!kyc.allRequiredUploaded)
            PrimaryButton(
              label: 'Finish documents',
              icon: Icons.folder_open,
              onPressed: () => context.push(Routes.kycDocuments),
            )
          else if (!_hasActiveVehicle && vehicles.isEmpty)
            PrimaryButton(
              label: 'Add a vehicle',
              icon: Icons.add,
              onPressed: () => context.push(Routes.vehicles),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  String get _headline => switch (kyc.status) {
    KycStatus.approved when _canGoOnline => "You're all set",
    KycStatus.approved => 'Documents approved',
    KycStatus.inReview => 'Under review',
    KycStatus.rejected => 'Action needed',
    KycStatus.pending => 'Submit your documents',
    KycStatus.unknown => 'Approval status',
  };

  String get _nextSteps {
    if (_canGoOnline) {
      return 'Head to the home screen, pick your vehicle and tap Go Online to '
          'start receiving trips.';
    }
    if (kyc.status == KycStatus.rejected) {
      return 'Re-upload the document noted above. Our team will review it '
          'again, usually within 24 hours.';
    }
    if (kyc.status == KycStatus.inReview) {
      return 'Our team is reviewing your documents and vehicle. This usually '
          "takes up to 24 hours — we'll notify you when it's done.";
    }
    return 'Upload your required documents and register a vehicle. Once '
        'submitted, our team reviews everything (usually within 24 hours).';
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        met ? Icons.check_circle : Icons.radio_button_unchecked,
        color: met ? AppColors.success : Theme.of(context).colorScheme.outline,
      ),
      title: Text(label),
    );
  }
}
