import 'dart:async';

import 'package:driver_app/core/config/app_config.dart';
import 'package:driver_app/core/core_providers.dart';
import 'package:driver_app/core/location/live_location_service.dart';
import 'package:driver_app/core/websocket/driver_socket.dart';
import 'package:driver_app/features/onboarding_kyc/data/models/onboarding_enums.dart';
import 'package:driver_app/features/trips/data/models/trip.dart';
import 'package:driver_app/features/trips/data/models/trip_enums.dart';
import 'package:driver_app/features/trips/data/trips_api.dart';
import 'package:driver_app/features/trips/data/trips_providers.dart';
import 'package:driver_app/features/trips/presentation/controllers/active_trip_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements TripsApi {}

/// A socket that records what it emits instead of touching a network.
class _SpySocket extends DriverSocket {
  _SpySocket()
    : super(
        const AppConfig(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'https://x',
          wsBaseUrl: 'https://x',
        ),
      );
  final emitted = <(String, Object?)>[];

  @override
  void emit(String event, Object? data) => emitted.add((event, data));
}

/// Hand-driven location service: tests push samples through [emit].
class _FakeLocation implements LiveLocationService {
  final _controller = StreamController<LocationSample>.broadcast();

  @override
  Stream<LocationSample> get samples => _controller.stream;
  @override
  bool get isRunning => true;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() => _controller.close();

  void emit(LocationSample s) => _controller.add(s);
}

Trip _trip(TripStatus status) => Trip(
  publicId: 'trp_1',
  status: status,
  vehicleType: VehicleType.car,
  pickup: const TripPlace(lat: 1, lng: 2),
  drop: const TripPlace(lat: 3, lng: 4),
  paymentMethod: PaymentMethod.cash,
  paymentStatus: PaymentStatus.pending,
  estimatedFare: 10000,
  createdAt: DateTime.utc(2026, 6, 2),
);

ProviderContainer _container(
  _MockApi api,
  _SpySocket socket,
  _FakeLocation loc,
) {
  final c = ProviderContainer(
    overrides: [
      tripsApiProvider.overrideWithValue(api),
      driverSocketProvider.overrideWithValue(socket),
      liveLocationServiceProvider.overrideWithValue(loc),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('build loads the current trip', () async {
    final api = _MockApi();
    when(api.currentTrip).thenAnswer((_) async => _trip(TripStatus.accepted));
    final c = _container(api, _SpySocket(), _FakeLocation());

    final trip = await c.read(activeTripControllerProvider.future);

    expect(trip?.status, TripStatus.accepted);
    expect(c.read(hasActiveTripProvider), isTrue);
  });

  test('arrived adopts the returned trip', () async {
    final api = _MockApi();
    when(api.currentTrip).thenAnswer((_) async => _trip(TripStatus.accepted));
    when(
      () => api.arrived('trp_1'),
    ).thenAnswer((_) async => _trip(TripStatus.arrived));
    final c = _container(api, _SpySocket(), _FakeLocation());
    await c.read(activeTripControllerProvider.future);

    final next = await c.read(activeTripControllerProvider.notifier).arrived();

    expect(next.status, TripStatus.arrived);
    expect(
      c.read(activeTripControllerProvider).value?.status,
      TripStatus.arrived,
    );
  });

  test('reconcile fetches a specific trip by id (terminal states)', () async {
    final api = _MockApi();
    when(api.currentTrip).thenAnswer((_) async => _trip(TripStatus.started));
    when(
      () => api.tripDetail('trp_1'),
    ).thenAnswer((_) async => _trip(TripStatus.ended));
    final c = _container(api, _SpySocket(), _FakeLocation());
    await c.read(activeTripControllerProvider.future);

    await c.read(activeTripControllerProvider.notifier).reconcile('trp_1');

    expect(
      c.read(activeTripControllerProvider).value?.status,
      TripStatus.ended,
    );
    expect(c.read(hasActiveTripProvider), isFalse);
  });

  test('streams location samples as trip.location while active', () async {
    final api = _MockApi();
    when(api.currentTrip).thenAnswer((_) async => _trip(TripStatus.started));
    final socket = _SpySocket();
    final loc = _FakeLocation();
    final c = _container(api, socket, loc);
    await c.read(activeTripControllerProvider.future);

    loc.emit(
      LocationSample(lat: 9.0, lng: 8.0, recordedAt: DateTime.utc(2026)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(socket.emitted, hasLength(1));
    final (event, data) = socket.emitted.first;
    expect(event, 'trip.location');
    expect((data! as Map)['tripId'], 'trp_1');
    expect((data as Map)['lat'], 9.0);
  });

  test('clear resets to no active trip', () async {
    final api = _MockApi();
    when(api.currentTrip).thenAnswer((_) async => _trip(TripStatus.started));
    final c = _container(api, _SpySocket(), _FakeLocation());
    await c.read(activeTripControllerProvider.future);

    c.read(activeTripControllerProvider.notifier).clear();

    expect(c.read(activeTripControllerProvider).value, isNull);
    expect(c.read(hasActiveTripProvider), isFalse);
  });
}
