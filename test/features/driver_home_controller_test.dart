import 'dart:async';

import 'package:driver_app/core/core_providers.dart';
import 'package:driver_app/core/error/app_failure.dart';
import 'package:driver_app/core/location/live_location_service.dart';
import 'package:driver_app/core/storage/app_database.dart';
import 'package:driver_app/features/driver_home/data/driver_home_providers.dart';
import 'package:driver_app/features/driver_home/data/driver_state_api.dart';
import 'package:driver_app/features/driver_home/data/location_ping_store.dart';
import 'package:driver_app/features/driver_home/data/models/driver_state.dart';
import 'package:driver_app/features/driver_home/presentation/controllers/driver_home_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements DriverStateApi {}

/// Hand-driven location service: tests push samples through [emit].
class _FakeLocation implements LiveLocationService {
  final _controller = StreamController<LocationSample>.broadcast();
  bool _running = false;

  @override
  Stream<LocationSample> get samples => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> start() async => _running = true;

  @override
  Future<void> stop() async => _running = false;

  @override
  void dispose() => _controller.close();

  void emit(LocationSample s) => _controller.add(s);
}

/// In-memory ping queue mirroring [LocationPingStore], no sqlite needed.
class _FakeQueue implements LocationPingStore {
  final List<LocationPing> _rows = [];
  int _nextId = 1;

  @override
  Future<void> enqueue({
    required double lat,
    required double lng,
    required DateTime recordedAt,
  }) async {
    _rows.add(
      LocationPing(id: _nextId++, lat: lat, lng: lng, recordedAt: recordedAt),
    );
  }

  @override
  Future<List<LocationPing>> pending() async => List.of(_rows);

  @override
  Future<void> remove(int id) async => _rows.removeWhere((r) => r.id == id);

  @override
  Future<void> clear() async => _rows.clear();
}

DriverState _state(DriverStatus status) => DriverState(status: status);

LocationSample _sample(double lat) =>
    LocationSample(lat: lat, lng: lat, recordedAt: DateTime.utc(2026, 6, 12));

void main() {
  late _MockApi api;
  late _FakeLocation location;
  late _FakeQueue queue;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        driverStateApiProvider.overrideWithValue(api),
        liveLocationServiceProvider.overrideWithValue(location),
        locationPingStoreProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    api = _MockApi();
    location = _FakeLocation();
    queue = _FakeQueue();
    when(
      () => api.getState(),
    ).thenAnswer((_) async => _state(DriverStatus.offline));
  });

  test('goOnline posts and starts streaming', () async {
    when(
      () => api.goOnline(any()),
    ).thenAnswer((_) async => _state(DriverStatus.online));

    final c = makeContainer();
    await c.read(driverHomeControllerProvider.future);
    await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');

    expect(
      c.read(driverHomeControllerProvider).value?.status,
      DriverStatus.online,
    );
    expect(location.isRunning, isTrue);
  });

  test(
    'a failed ping is queued, then flushed after the next success',
    () async {
      when(
        () => api.goOnline(any()),
      ).thenAnswer((_) async => _state(DriverStatus.online));

      var calls = 0;
      when(
        () => api.reportLocation(
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          speed: any(named: 'speed'),
          bearing: any(named: 'bearing'),
        ),
      ).thenAnswer((_) async {
        calls++;
        // The very first ping fails (network blip); everything after succeeds.
        if (calls == 1) {
          throw const AppFailure(code: 'NETWORK', message: 'No internet.');
        }
        return _state(DriverStatus.online);
      });

      final c = makeContainer();
      await c.read(driverHomeControllerProvider.future);
      await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');

      // First ping fails → buffered.
      location.emit(_sample(1));
      await pumpEventQueue();
      expect((await queue.pending()).length, 1);

      // Next ping succeeds → it reports AND drains the buffered one.
      location.emit(_sample(2));
      await pumpEventQueue();
      expect(await queue.pending(), isEmpty);
    },
  );

  test('goOffline stops streaming and clears the queue', () async {
    when(
      () => api.goOnline(any()),
    ).thenAnswer((_) async => _state(DriverStatus.online));
    when(
      () => api.goOffline(),
    ).thenAnswer((_) async => _state(DriverStatus.offline));

    final c = makeContainer();
    await c.read(driverHomeControllerProvider.future);
    await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');

    await queue.enqueue(lat: 1, lng: 1, recordedAt: DateTime.utc(2026));
    await c.read(driverHomeControllerProvider.notifier).goOffline();

    expect(
      c.read(driverHomeControllerProvider).value?.status,
      DriverStatus.offline,
    );
    expect(location.isRunning, isFalse);
    expect(await queue.pending(), isEmpty);
  });

  test('on relaunch while server says ONLINE, the pump resumes', () async {
    when(
      () => api.getState(),
    ).thenAnswer((_) async => _state(DriverStatus.online));

    final c = makeContainer();
    await c.read(driverHomeControllerProvider.future);

    expect(location.isRunning, isTrue);
  });
}
