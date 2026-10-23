import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Draft KYC uploads — lets a dropped upload resume instead of starting over
/// (D2). One row per (docType) in flight.
class KycDrafts extends Table {
  TextColumn get docType => text()();
  TextColumn get localFilePath => text()();
  TextColumn get docNumber => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {docType};
}

/// Minimal local DB — only where offline actually matters. Keep it small;
/// everything else is server-truth.
@DriftDatabase(tables: [KycDrafts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// v2 dropped the `location_pings` replay queue: the server matches on the
  /// latest position, so stale fixes were worse than none.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS location_pings');
      }
    },
  );

  static QueryExecutor _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'driver_app.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
