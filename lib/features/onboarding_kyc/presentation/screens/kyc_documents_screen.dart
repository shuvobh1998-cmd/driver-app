import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/kyc_document.dart';
import '../../data/models/kyc_status_summary.dart';
import '../../data/models/onboarding_enums.dart';
import '../../data/onboarding_providers.dart';
import '../controllers/kyc_upload_controller.dart';
import '../widgets/doc_capture_sheet.dart';
import '../widgets/doc_upload_row.dart';
import '../widgets/kyc_status_badge.dart';

/// The KYC document checklist: one [DocUploadRow] per supported doc type,
/// each reflecting live `kyc/status` and the in-flight upload state. Aadhaar +
/// DL are required; RC / Insurance / Permit are optional.
class KycDocumentsScreen extends ConsumerWidget {
  const KycDocumentsScreen({super.key});

  /// Display order: required first, then optional.
  static const _docOrder = [
    KycDocType.aadhaar,
    KycDocType.dl,
    KycDocType.rc,
    KycDocType.insurance,
    KycDocType.permit,
  ];

  static const _defaultRequired = {KycDocType.aadhaar, KycDocType.dl};

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(kycStatusProvider);
    ref.invalidate(kycDocumentsProvider);
    await Future.wait([
      ref.read(kycStatusProvider.future),
      ref.read(kycDocumentsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(kycStatusProvider);
    final docs = ref.watch(kycDocumentsProvider);

    return AppScaffold(
      title: 'Documents',
      body: switch ((status, docs)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => ErrorState(
          message: messageForError(error),
          onRetry: () => _refresh(ref),
        ),
        (AsyncData(value: final s), AsyncData(value: final d)) => _DocList(
          status: s,
          documents: d,
          onRefresh: () => _refresh(ref),
        ),
        _ => const LoadingState(message: 'Loading your documents…'),
      },
    );
  }
}

class _DocList extends ConsumerWidget {
  const _DocList({
    required this.status,
    required this.documents,
    required this.onRefresh,
  });

  final KycStatusSummary status;
  final List<KycDocument> documents;
  final Future<void> Function() onRefresh;

  KycDocument? _docFor(KycDocType type) {
    for (final d in documents) {
      if (d.docType == type) return d;
    }
    return null;
  }

  bool _isRequired(KycDocType type) {
    if (status.requiredDocs.isNotEmpty) {
      return status.requiredDocs.contains(type);
    }
    return KycDocumentsScreen._defaultRequired.contains(type);
  }

  Future<void> _capture(
    BuildContext context,
    WidgetRef ref,
    KycDocType type,
  ) async {
    final existing = _docFor(type);
    final result = await DocCaptureSheet.show(
      context,
      docType: type,
      initialDocNumber: existing?.docNumber,
    );
    if (result == null) return;
    await ref
        .read(kycUploadControllerProvider.notifier)
        .captureAndUpload(
          docType: type,
          source: result.source,
          docNumber: result.docNumber,
        );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    KycDocument doc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text('This removes your ${doc.docType.label}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(driverApiProvider).deleteDocument(doc.id);
      ref.invalidate(kycStatusProvider);
      ref.invalidate(kycDocumentsProvider);
      ref.invalidate(driverProfileProvider);
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploads = ref.watch(kycUploadControllerProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Upload clear photos or PDFs. Files are compressed before '
                  'upload (max 5MB).',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              KycStatusBadge(status: status.status),
            ],
          ),
          if (status.status == KycStatus.rejected &&
              status.rejectedReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              status.rejectedReason!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final type in KycDocumentsScreen._docOrder)
            DocUploadRow(
              docType: type,
              isRequired: _isRequired(type),
              overallStatus: status.status,
              uploadState: uploads[type] ?? const DocUploadState(),
              document: _docFor(type),
              rejectedReason: status.rejectedReason,
              onUpload: () => _capture(context, ref, type),
              onRetry: () =>
                  ref.read(kycUploadControllerProvider.notifier).retry(type),
              onRemove: _docFor(type) == null
                  ? null
                  : () => _remove(context, ref, _docFor(type)!),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
