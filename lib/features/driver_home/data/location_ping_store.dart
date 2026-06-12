import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// Buffers location pings in the `location_pings` drift table while the network
/// is down, so a blip while online never drops a ping. The pump enqueues on a
/// failed POST and drains (oldest-first) after a successful one.
class LocationPingStore {
  LocationPingStore(this._db);

  final AppDatabase _db;

  /// Caps the buffer so a long outage can't grow it without bound; the oldest
  /// pings are the least useful once the driver has moved on.
  static const int maxQueued = 200;

  Future<void> enqueue({
    required double lat,
    required double lng,
    required DateTime recordedAt,
  }) async {
    await _db
        .into(_db.locationPings)
        .insert(
          LocationPingsCompanion.insert(
            lat: lat,
            lng: lng,
            recordedAt: recordedAt,
          ),
        );
    await _trim();
  }

  /// Oldest-first, so a flush replays pings in the order they happened.
  Future<List<LocationPing>> pending() {
    return (_db.select(_db.locationPings)
          ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)])
          ..limit(maxQueued))
        .get();
  }

  Future<void> remove(int id) {
    return (_db.delete(_db.locationPings)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clear() => _db.delete(_db.locationPings).go();

  /// Drops the oldest rows beyond [maxQueued].
  Future<void> _trim() async {
    final count =
        await (_db.selectOnly(_db.locationPings)
              ..addColumns([_db.locationPings.id.count()]))
            .map((r) => r.read(_db.locationPings.id.count()) ?? 0)
            .getSingle();
    if (count <= maxQueued) return;
    final overflow = count - maxQueued;
    final oldest =
        await (_db.select(_db.locationPings)
              ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)])
              ..limit(overflow))
            .get();
    for (final row in oldest) {
      await remove(row.id);
    }
  }
}
