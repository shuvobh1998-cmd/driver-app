import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Queued location pings — buffered while the network is down and flushed on
/// reconnect (D3), so no "online" ping is lost.
class LocationPings extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  DateTimeColumn get recordedAt => dateTime()();
}

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

/// Minimal local DB — only the two places offline actually matters. Keep it
/// small; everything else is server-truth.
@DriftDatabase(tables: [LocationPings, KycDrafts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'driver_app.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
