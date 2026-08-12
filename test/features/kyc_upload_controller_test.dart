import 'dart:io';

import 'package:driver_app/core/error/app_failure.dart';
import 'package:driver_app/core/storage/app_database.dart';
import 'package:driver_app/features/onboarding_kyc/data/driver_api.dart';
import 'package:driver_app/features/onboarding_kyc/data/kyc_draft_store.dart';
import 'package:driver_app/features/onboarding_kyc/data/models/kyc_document.dart';
import 'package:driver_app/features/onboarding_kyc/data/models/onboarding_enums.dart';
import 'package:driver_app/features/onboarding_kyc/data/onboarding_providers.dart';
import 'package:driver_app/features/onboarding_kyc/presentation/controllers/kyc_upload_controller.dart';
import 'package:driver_app/shared/utils/image_pick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class _MockDriverApi extends Mock implements DriverApi {}

/// In-memory draft store recording saves/removals.
class _FakeDraftStore implements KycDraftStore {
  final List<KycDocType> saved = [];
  final List<KycDocType> removed = [];

  @override
  Future<Map<KycDocType, KycDraft>> all() async => {};

  @override
  Future<void> save({
    required KycDocType docType,
    required String localFilePath,
    String? docNumber,
  }) async => saved.add(docType);

  @override
  Future<void> remove(KycDocType docType) async => removed.add(docType);
}

/// Picker that returns a fixed path (a "captured" file), or throws when
/// [tooLarge] is set — standing in for the pre-upload size guard tripping.
///
/// The path must point at a file that really exists: the controller re-verifies
/// every draft on disk before sending, so a fictional path is now rejected.
class _FakePicker implements ImagePickService {
  _FakePicker({this.tooLarge = false, required this.path});

  final bool tooLarge;
  final String path;

  /// Sources the controller asked for, in order.
  final List<PickSource> requested = [];

  @override
  Future<String?> pick(ImageSource source) async => path;

  @override
  Future<String?> pickDocument(PickSource source) async {
    requested.add(source);
    if (tooLarge) throw const FileTooLargeException(7 * 1024 * 1024);
    return path;
  }
}

/// Creates a real on-disk file so the controller's disk checks pass.
String _makeFile(Directory dir, String name, {int bytes = 1024}) {
  final f = File(p.join(dir.path, name))
    ..writeAsBytesSync(List.filled(bytes, 0));
  return f.path;
}

KycDocument _doc() => const KycDocument(
  id: '1',
  docType: KycDocType.aadhaar,
  fileUrl: 'https://example.test/a.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 1024,
  verified: false,
);

void main() {
  setUpAll(() => registerFallbackValue(KycDocType.aadhaar));

  late _MockDriverApi api;
  late _FakeDraftStore drafts;
  late Directory tmp;
  late String jpgPath;

  ProviderContainer makeContainer([_FakePicker? picker]) {
    final c = ProviderContainer(
      overrides: [
        driverApiProvider.overrideWithValue(api),
        kycDraftStoreProvider.overrideWithValue(drafts),
        imagePickServiceProvider.overrideWithValue(
          picker ?? _FakePicker(path: jpgPath),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    api = _MockDriverApi();
    drafts = _FakeDraftStore();
    tmp = Directory.systemTemp.createTempSync('kyc_upload_test');
    jpgPath = _makeFile(tmp, 'aadhaar.jpg');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('capture + upload success clears state and drops the draft', () async {
    when(
      () => api.uploadDocument(
        docType: any(named: 'docType'),
        filePath: any(named: 'filePath'),
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _doc());

    final c = makeContainer();
    final controller = c.read(kycUploadControllerProvider.notifier);

    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.camera,
    );

    final state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.idle);
    expect(state?.draftPath, isNull);
    expect(drafts.saved, [KycDocType.aadhaar]);
    expect(drafts.removed, [KycDocType.aadhaar]);
  });

  test('failed upload keeps the draft, then retry succeeds', () async {
    var attempt = 0;
    when(
      () => api.uploadDocument(
        docType: any(named: 'docType'),
        filePath: any(named: 'filePath'),
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      attempt++;
      if (attempt == 1) {
        throw const AppFailure(code: 'NETWORK', message: 'No internet.');
      }
      return _doc();
    });

    final c = makeContainer();
    final controller = c.read(kycUploadControllerProvider.notifier);

    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.gallery,
    );

    var state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.error);
    expect(state?.draftPath, jpgPath);
    expect(state?.errorMessage, 'No internet.');
    expect(drafts.removed, isEmpty); // draft survives a failed upload

    await controller.retry(KycDocType.aadhaar);

    state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.idle);
    expect(state?.draftPath, isNull);
    expect(drafts.removed, [KycDocType.aadhaar]);
  });

  test('an over-cap file errors before uploading and saves no draft', () async {
    final c = makeContainer(_FakePicker(tooLarge: true, path: jpgPath));
    final controller = c.read(kycUploadControllerProvider.notifier);

    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.file,
    );

    final state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.error);
    // The message names the size and the limit so the driver can act on it.
    expect(state?.errorMessage, contains('7.0MB'));
    expect(state?.errorMessage, contains('5MB'));
    // Nothing was drafted and nothing hit the wire.
    expect(drafts.saved, isEmpty);
    verifyNever(
      () => api.uploadDocument(
        docType: any(named: 'docType'),
        filePath: any(named: 'filePath'),
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('a PDF picked from files uploads unchanged', () async {
    when(
      () => api.uploadDocument(
        docType: any(named: 'docType'),
        filePath: any(named: 'filePath'),
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _doc());

    final pdfPath = _makeFile(tmp, 'aadhaar.pdf');
    final picker = _FakePicker(path: pdfPath);
    final c = makeContainer(picker);
    final controller = c.read(kycUploadControllerProvider.notifier);

    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.file,
    );

    expect(picker.requested, [PickSource.file]);
    // The PDF path reaches the API as-is — no JPEG re-encode.
    verify(
      () => api.uploadDocument(
        docType: KycDocType.aadhaar,
        filePath: pdfPath,
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    expect(
      c.read(kycUploadControllerProvider)[KycDocType.aadhaar]?.phase,
      UploadPhase.idle,
    );
  });

  test('a draft whose file vanished is dropped, not retried forever', () async {
    final c = makeContainer();
    final controller = c.read(kycUploadControllerProvider.notifier);

    when(
      () => api.uploadDocument(
        docType: any(named: 'docType'),
        filePath: any(named: 'filePath'),
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _doc());

    // Capture succeeds, then the OS reclaims the temp file before the retry —
    // the real scenario for a draft that outlives its temp directory.
    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.camera,
    );
    File(jpgPath).deleteSync();

    // Re-seed a draft pointing at the now-missing file, then retry it.
    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.camera,
    );

    final state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.error);
    expect(state?.errorMessage, contains('no longer on your device'));
    // Draft cleared, so the row asks for a fresh capture instead of offering a
    // retry that could never succeed.
    expect(state?.draftPath, isNull);
    expect(drafts.removed, contains(KycDocType.aadhaar));
  });

  test('an over-cap draft is caught on retry, not just at pick time', () async {
    // Draft was within budget when captured, then replaced on disk by something
    // over the cap — retry must re-check rather than trusting the pick.
    final c = makeContainer();
    final controller = c.read(kycUploadControllerProvider.notifier);

    when(
      () => api.uploadDocument(
        docType: any(named: 'docType'),
        filePath: any(named: 'filePath'),
        docNumber: any(named: 'docNumber'),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      throw const AppFailure(code: 'NETWORK', message: 'No internet.');
    });

    await controller.captureAndUpload(
      docType: KycDocType.aadhaar,
      source: PickSource.camera,
    );
    expect(
      c.read(kycUploadControllerProvider)[KycDocType.aadhaar]?.draftPath,
      jpgPath,
    );

    // Swell the draft past the 5MB cap, then retry.
    File(jpgPath).writeAsBytesSync(List.filled(6 * 1024 * 1024, 0));
    await controller.retry(KycDocType.aadhaar);

    final state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.error);
    expect(state?.errorMessage, contains('6.0MB'));
    // Still retryable — the file exists, it's just too big.
    expect(state?.draftPath, jpgPath);
  });
}
