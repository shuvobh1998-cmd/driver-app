import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/kyc_document.dart';
import '../../data/models/onboarding_enums.dart';
import '../controllers/kyc_upload_controller.dart';

/// The visual state a [DocUploadRow] resolves to from its inputs.
enum _DocState {
  missing,
  pendingDraft,
  preparing,
  uploading,
  uploaded,
  inReview,
  approved,
  rejected,
  error,
}

/// One row per KYC document type, with five+ visual states (missing · ready ·
/// uploading · uploaded/in-review · approved · rejected) plus a thumbnail and
/// the single relevant action.
class DocUploadRow extends StatelessWidget {
  const DocUploadRow({
    super.key,
    required this.docType,
    required this.isRequired,
    required this.overallStatus,
    required this.uploadState,
    required this.onUpload,
    required this.onRetry,
    this.document,
    this.rejectedReason,
    this.onRemove,
  });

  final KycDocType docType;
  final bool isRequired;
  final KycStatus overallStatus;
  final DocUploadState uploadState;
  final KycDocument? document;
  final String? rejectedReason;

  /// Opens the capture sheet (upload / replace / re-upload).
  final VoidCallback onUpload;

  /// Re-sends a saved-but-unsent draft (after a failed/interrupted upload).
  final VoidCallback onRetry;

  /// Removes the uploaded document; null hides the remove action.
  final VoidCallback? onRemove;

  _DocState get _resolved {
    switch (uploadState.phase) {
      case UploadPhase.preparing:
        return _DocState.preparing;
      case UploadPhase.uploading:
        return _DocState.uploading;
      case UploadPhase.error:
        return _DocState.error;
      case UploadPhase.idle:
        break;
    }
    if (document != null) {
      if (document!.verified || overallStatus == KycStatus.approved) {
        return _DocState.approved;
      }
      if (overallStatus == KycStatus.rejected) return _DocState.rejected;
      if (overallStatus == KycStatus.inReview) return _DocState.inReview;
      return _DocState.uploaded;
    }
    if (uploadState.hasPendingDraft) return _DocState.pendingDraft;
    return _DocState.missing;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _resolved;
    final (tone, statusText) = _statusFor(state);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumbnail(context, state),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(docType.label, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        isRequired ? 'Required' : 'Optional',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StatusBadge(label: statusText, tone: tone),
                    ],
                  ),
                ),
                _trailing(context, state),
              ],
            ),
            if (state == _DocState.uploading) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: uploadState.progress),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${(uploadState.progress * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (state == _DocState.rejected && rejectedReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                rejectedReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
            if (state == _DocState.error &&
                uploadState.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                uploadState.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (StatusTone, String) _statusFor(_DocState state) => switch (state) {
    _DocState.missing => (StatusTone.neutral, 'Not uploaded'),
    _DocState.pendingDraft => (StatusTone.warning, 'Ready to upload'),
    _DocState.preparing => (StatusTone.info, 'Preparing…'),
    _DocState.uploading => (StatusTone.info, 'Uploading…'),
    _DocState.uploaded => (StatusTone.info, 'Uploaded'),
    _DocState.inReview => (StatusTone.warning, 'In review'),
    _DocState.approved => (StatusTone.success, 'Approved'),
    _DocState.rejected => (StatusTone.danger, 'Rejected'),
    _DocState.error => (StatusTone.danger, 'Upload failed'),
  };

  Widget _thumbnail(BuildContext context, _DocState state) {
    const size = 56.0;
    Widget box(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: SizedBox(width: size, height: size, child: child),
    );

    final doc = document;
    if (doc != null && !doc.isPdf) {
      return box(Image.network(doc.fileUrl, fit: BoxFit.cover));
    }
    if (doc != null && doc.isPdf) {
      return box(
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.picture_as_pdf),
        ),
      );
    }
    final draft = uploadState.draftPath;
    if (draft != null) {
      return box(Image.file(File(draft), fit: BoxFit.cover));
    }
    return box(
      Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.description_outlined),
      ),
    );
  }

  Widget _trailing(BuildContext context, _DocState state) {
    switch (state) {
      case _DocState.preparing:
      case _DocState.uploading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case _DocState.missing:
        return TextButton(onPressed: onUpload, child: const Text('Upload'));
      case _DocState.pendingDraft:
        return TextButton(onPressed: onRetry, child: const Text('Upload now'));
      case _DocState.error:
        return TextButton(onPressed: onRetry, child: const Text('Retry'));
      case _DocState.approved:
        return const Icon(Icons.verified, color: AppColors.success);
      case _DocState.uploaded:
      case _DocState.inReview:
      case _DocState.rejected:
        return PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'replace') onUpload();
            if (v == 'remove') onRemove?.call();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'replace', child: Text('Replace')),
            if (onRemove != null)
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
          ],
        );
    }
  }
}
