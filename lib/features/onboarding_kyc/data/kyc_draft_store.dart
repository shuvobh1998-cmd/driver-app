import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import 'models/onboarding_enums.dart';

/// Persists in-flight KYC uploads in the `kyc_drafts` drift table so a dropped
/// or killed upload resumes from the saved file instead of starting over.
/// One row per [KycDocType].
class KycDraftStore {
  KycDraftStore(this._db);

  final AppDatabase _db;

  /// All saved drafts, keyed by doc type (unknown types are skipped).
  Future<Map<KycDocType, KycDraft>> all() async {
    final rows = await _db.select(_db.kycDrafts).get();
    final out = <KycDocType, KycDraft>{};
    for (final row in rows) {
      final type = _typeFromWire(row.docType);
      if (type != null) out[type] = row;
    }
    return out;
  }

  Future<void> save({
    required KycDocType docType,
    required String localFilePath,
    String? docNumber,
  }) {
    return _db
        .into(_db.kycDrafts)
        .insertOnConflictUpdate(
          KycDraftsCompanion.insert(
            docType: docType.wireValue,
            localFilePath: localFilePath,
            docNumber: Value(docNumber),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> remove(KycDocType docType) {
    return (_db.delete(
      _db.kycDrafts,
    )..where((t) => t.docType.equals(docType.wireValue))).go();
  }

  KycDocType? _typeFromWire(String wire) {
    for (final t in KycDocType.values) {
      if (t != KycDocType.unknown && t.wireValue == wire) return t;
    }
    return null;
  }
}
