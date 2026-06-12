import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/onboarding_enums.dart';
import '../../data/onboarding_providers.dart';

/// Where a single document's upload stands.
enum UploadPhase { idle, preparing, uploading, error }

/// Per-document upload state. A non-null [draftPath] with [UploadPhase.idle] or
/// [UploadPhase.error] means a captured file is saved locally and waiting to be
/// (re)sent — the basis for resume-after-kill.
class DocUploadState {
  const DocUploadState({
    this.phase = UploadPhase.idle,
    this.progress = 0,
    this.draftPath,
    this.errorMessage,
  });

  final UploadPhase phase;
  final double progress;
  final String? draftPath;
  final String? errorMessage;

  bool get isBusy =>
      phase == UploadPhase.preparing || phase == UploadPhase.uploading;

  /// A file is captured but not yet successfully uploaded.
  bool get hasPendingDraft =>
      draftPath != null &&
      (phase == UploadPhase.idle || phase == UploadPhase.error);

  DocUploadState copyWith({
    UploadPhase? phase,
    double? progress,
    String? draftPath,
    String? errorMessage,
  }) => DocUploadState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    draftPath: draftPath ?? this.draftPath,
    errorMessage: errorMessage,
  );
}

/// Drives KYC document uploads: compress → persist a local draft → multipart
/// upload with progress → on success drop the draft and refresh the KYC
/// providers. A failed or interrupted upload keeps its draft so the row offers
/// a one-tap retry (and resumes after the app is killed).
class KycUploadController extends Notifier<Map<KycDocType, DocUploadState>> {
  @override
  Map<KycDocType, DocUploadState> build() {
    // Seed from any drafts persisted by an earlier (interrupted) session.
    Future.microtask(_loadDrafts);
    return const {};
  }

  Future<void> _loadDrafts() async {
    final drafts = await ref.read(kycDraftStoreProvider).all();
    if (drafts.isEmpty) return;
    state = {
      ...state,
      for (final entry in drafts.entries)
        if (state[entry.key]?.isBusy != true)
          entry.key: DocUploadState(draftPath: entry.value.localFilePath),
    };
  }

  void _set(KycDocType type, DocUploadState s) => state = {...state, type: s};

  /// Captures a photo (or picks from gallery), saves it as a draft, then
  /// uploads it. A cancelled picker is a no-op.
  Future<void> captureAndUpload({
    required KycDocType docType,
    required ImageSource source,
    String? docNumber,
  }) async {
    _set(docType, const DocUploadState(phase: UploadPhase.preparing));
    final String? path;
    try {
      path = await ref.read(imagePickServiceProvider).pick(source);
    } catch (_) {
      _set(
        docType,
        const DocUploadState(
          phase: UploadPhase.error,
          errorMessage: 'Could not read that image. Try another.',
        ),
      );
      return;
    }
    if (path == null) {
      // Picker dismissed — fall back to any existing draft, else clear.
      final existing = state[docType]?.draftPath;
      _set(
        docType,
        existing == null
            ? const DocUploadState()
            : DocUploadState(draftPath: existing),
      );
      return;
    }

    await ref
        .read(kycDraftStoreProvider)
        .save(docType: docType, localFilePath: path, docNumber: docNumber);
    await _upload(docType, path, docNumber);
  }

  /// Re-sends a previously captured draft (after a failed/interrupted upload).
  Future<void> retry(KycDocType docType, {String? docNumber}) async {
    final path = state[docType]?.draftPath;
    if (path == null) return;
    await _upload(docType, path, docNumber);
  }

  Future<void> _upload(
    KycDocType docType,
    String path,
    String? docNumber,
  ) async {
    _set(
      docType,
      DocUploadState(
        phase: UploadPhase.uploading,
        progress: 0,
        draftPath: path,
      ),
    );
    try {
      await ref
          .read(driverApiProvider)
          .uploadDocument(
            docType: docType,
            filePath: path,
            docNumber: docNumber,
            onProgress: (p) {
              final current = state[docType];
              if (current?.phase == UploadPhase.uploading) {
                _set(docType, current!.copyWith(progress: p));
              }
            },
          );
      await ref.read(kycDraftStoreProvider).remove(docType);
      _set(docType, const DocUploadState());
      _refreshKyc();
    } catch (e) {
      _set(
        docType,
        DocUploadState(
          phase: UploadPhase.error,
          draftPath: path,
          errorMessage: messageForError(e),
        ),
      );
    }
  }

  void _refreshKyc() {
    ref.invalidate(kycStatusProvider);
    ref.invalidate(kycDocumentsProvider);
    ref.invalidate(driverProfileProvider);
  }
}

final kycUploadControllerProvider =
    NotifierProvider<KycUploadController, Map<KycDocType, DocUploadState>>(
      KycUploadController.new,
    );
