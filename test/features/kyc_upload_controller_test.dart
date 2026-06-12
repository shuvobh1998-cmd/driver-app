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

/// Picker that always returns a fixed path (a "captured" file).
class _FakePicker implements ImagePickService {
  @override
  Future<String?> pick(ImageSource source) async => '/tmp/aadhaar.jpg';
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

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        driverApiProvider.overrideWithValue(api),
        kycDraftStoreProvider.overrideWithValue(drafts),
        imagePickServiceProvider.overrideWithValue(_FakePicker()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    api = _MockDriverApi();
    drafts = _FakeDraftStore();
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
      source: ImageSource.camera,
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
      source: ImageSource.gallery,
    );

    var state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.error);
    expect(state?.draftPath, '/tmp/aadhaar.jpg');
    expect(state?.errorMessage, 'No internet.');
    expect(drafts.removed, isEmpty); // draft survives a failed upload

    await controller.retry(KycDocType.aadhaar);

    state = c.read(kycUploadControllerProvider)[KycDocType.aadhaar];
    expect(state?.phase, UploadPhase.idle);
    expect(state?.draftPath, isNull);
    expect(drafts.removed, [KycDocType.aadhaar]);
  });
}
