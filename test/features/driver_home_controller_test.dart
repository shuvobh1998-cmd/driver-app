import 'dart:async';

import 'package:dio/dio.dart';
import 'package:driver_app/core/core_providers.dart';
import 'package:driver_app/core/location/live_location_service.dart';
import 'package:driver_app/features/driver_home/data/driver_home_providers.dart';
import 'package:driver_app/features/driver_home/data/driver_state_api.dart';
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

  /// When set, [start] fails with it (e.g. permission revoked since last run).
  Object? startError;

  @override
  Stream<LocationSample> get samples => _controller.stream;

  @override
  Stream<LocationSample> get fixes => const Stream.empty();

  @override
  ({double lat, double lng})? get demoLocation => null;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> start() async {
    if (startError case final e?) throw e;
    _running = true;
  }

  @override
  Future<void> stop() async => _running = false;

  @override
  void dispose() => _controller.close();

  void emit(LocationSample s) => _controller.add(s);
}

DriverState _state(DriverStatus status) => DriverState(status: status);

LocationSample _sample(double lat) =>
    LocationSample(lat: lat, lng: lat, recordedAt: DateTime.utc(2026, 6, 12));

void main() {
  late _MockApi api;
  late _FakeLocation location;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        driverStateApiProvider.overrideWithValue(api),
        liveLocationServiceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    api = _MockApi();
    location = _FakeLocation();
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

  void stubPings(Future<DriverState> Function(double lat) answer) {
    when(
      () => api.reportLocation(
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        speed: any(named: 'speed'),
        bearing: any(named: 'bearing'),
      ),
    ).thenAnswer((inv) => answer(inv.namedArguments[#lat] as double));
  }

  test('a ping lost to a network blip is dropped, not replayed', () async {
    when(
      () => api.goOnline(any()),
    ).thenAnswer((_) async => _state(DriverStatus.online));
    final sent = <double>[];
    stubPings((lat) async {
      sent.add(lat);
      // The very first ping fails with no response (network blip).
      if (sent.length == 1) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/drivers/me/location'),
          reason: 'offline',
        );
      }
      return _state(DriverStatus.online);
    });

    final c = makeContainer();
    await c.read(driverHomeControllerProvider.future);
    await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');

    location.emit(_sample(1));
    await pumpEventQueue();
    location.emit(_sample(2));
    await pumpEventQueue();

    // Only the fresh fix follows the failure — the stale one never resurfaces
    // to put the driver back where they were.
    expect(sent, [1, 2]);
    expect(location.isRunning, isTrue);
  });

  test(
    'a refused ping re-syncs and stops the pump once swept offline',
    () async {
      when(
        () => api.goOnline(any()),
      ).thenAnswer((_) async => _state(DriverStatus.online));
      stubPings((_) async {
        final options = RequestOptions(path: '/drivers/me/location');
        throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 409),
        );
      });

      final c = makeContainer();
      await c.read(driverHomeControllerProvider.future);
      await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');

      // The server swept us offline (90 s without a ping) and refuses the next.
      location.emit(_sample(1));
      await pumpEventQueue();

      expect(
        c.read(driverHomeControllerProvider).value?.status,
        DriverStatus.offline,
      );
      expect(location.isRunning, isFalse);
    },
  );

  test('goOffline stops streaming', () async {
    when(
      () => api.goOnline(any()),
    ).thenAnswer((_) async => _state(DriverStatus.online));
    when(
      () => api.goOffline(),
    ).thenAnswer((_) async => _state(DriverStatus.offline));

    final c = makeContainer();
    await c.read(driverHomeControllerProvider.future);
    await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');
    await c.read(driverHomeControllerProvider.notifier).goOffline();

    expect(
      c.read(driverHomeControllerProvider).value?.status,
      DriverStatus.offline,
    );
    expect(location.isRunning, isFalse);
  });

  test('on relaunch while server says ONLINE, the pump resumes', () async {
    when(
      () => api.getState(),
    ).thenAnswer((_) async => _state(DriverStatus.online));

    final c = makeContainer();
    await c.read(driverHomeControllerProvider.future);

    expect(location.isRunning, isTrue);
  });

  test(
    'on relaunch, a location failure still loads the server state',
    () async {
      when(
        () => api.getState(),
      ).thenAnswer((_) async => _state(DriverStatus.online));
      location.startError = Exception('location permission denied');

      final c = makeContainer();
      await c.read(driverHomeControllerProvider.future);

      // The home screen needs a state to enable its button; without one it
      // shows a fallback "Offline" and a dead Go Online.
      expect(
        c.read(driverHomeControllerProvider).value?.status,
        DriverStatus.online,
      );
      expect(location.isRunning, isFalse);
    },
  );

  test(
    'a refused goOnline keeps the last state so the button stays live',
    () async {
      when(
        () => api.goOnline(any()),
      ).thenThrow(Exception('VEHICLE_NOT_APPROVED'));

      final c = makeContainer();
      await c.read(driverHomeControllerProvider.future);
      await c.read(driverHomeControllerProvider.notifier).goOnline('veh_1');

      final s = c.read(driverHomeControllerProvider);
      expect(s.hasError, isTrue);
      expect(s.value?.status, DriverStatus.offline);
    },
  );
}
