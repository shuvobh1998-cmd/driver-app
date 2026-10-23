import 'package:dio/dio.dart';
import 'package:driver_app/features/onboarding_kyc/data/models/onboarding_enums.dart';
import 'package:driver_app/features/trips/data/models/trip.dart';
import 'package:driver_app/features/trips/data/models/trip_enums.dart';
import 'package:driver_app/features/trips/data/models/trip_offer.dart';
import 'package:driver_app/features/trips/data/trips_api.dart';
import 'package:driver_app/features/trips/data/trips_providers.dart';
import 'package:driver_app/features/trips/presentation/controllers/trip_offer_controller.dart';
import 'package:driver_app/features/trips/presentation/widgets/next_action_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements TripsApi {}

DioException _httpError(int status) {
  final options = RequestOptions(path: '/drivers/me/trip-offers/off_1/accept');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  group('TripOffer.tryParse', () {
    test('parses a well-formed trip.offered payload', () {
      final future = DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 15))
          .toIso8601String();
      final offer = TripOffer.tryParse({
        'offerId': 'off_1',
        'rideRequestId': 'req_1',
        'vehicleType': 'AUTO',
        'pickup': {'lat': 22.5, 'lng': 88.3},
        'distanceMeters': 1450,
        'expiresAt': future,
      });

      expect(offer, isNotNull);
      expect(offer!.offerId, 'off_1');
      expect(offer.vehicleType, VehicleType.auto);
      expect(offer.pickup.lat, 22.5);
      expect(offer.distanceMeters, 1450);
      expect(offer.isExpired, isFalse);
      expect(offer.secondsLeft, greaterThan(0));
    });

    test('reads addresses and notes nested like the trip', () {
      final offer = TripOffer.tryParse({
        'offerId': 'off_1',
        'pickup': {'lat': 22.5, 'lng': 88.3, 'address': 'Park Street'},
        'drop': {'lat': 22.6, 'lng': 88.4, 'address': 'Sector V'},
        'notes': 'Bring helmet',
      })!;

      expect(offer.pickup.address, 'Park Street');
      expect(offer.dropAddress, 'Sector V');
      expect(offer.notes, 'Bring helmet');
    });

    test('reads addresses flat like the ride request', () {
      final offer = TripOffer.tryParse({
        'offerId': 'off_1',
        'pickup': {'lat': 22.5, 'lng': 88.3},
        'pickupAddress': 'Park Street',
        'dropAddress': 'Sector V',
        'notes': '   ',
      })!;

      expect(offer.pickup.address, 'Park Street');
      expect(offer.dropAddress, 'Sector V');
      expect(offer.notes, isNull, reason: 'blank notes are not shown');
    });

    test('returns null when offerId or pickup is missing', () {
      expect(
        TripOffer.tryParse({
          'pickup': {'lat': 1, 'lng': 2},
        }),
        isNull,
      );
      expect(TripOffer.tryParse({'offerId': 'off_1'}), isNull);
      expect(TripOffer.tryParse('not a map'), isNull);
    });

    test('defaults a malformed expiry to a short live window', () {
      final offer = TripOffer.tryParse({
        'offerId': 'off_1',
        'pickup': {'lat': 22.5, 'lng': 88.3},
        'expiresAt': 'garbage',
      });
      expect(offer, isNotNull);
      expect(offer!.isExpired, isFalse);
    });

    test('marks an already-past expiry as expired', () {
      final past = DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 5))
          .toIso8601String();
      final offer = TripOffer.tryParse({
        'offerId': 'off_1',
        'pickup': {'lat': 22.5, 'lng': 88.3},
        'expiresAt': past,
      });
      expect(offer!.isExpired, isTrue);
      expect(offer.secondsLeft, 0);
    });
  });

  group('TripAction.forStatus', () {
    test('derives one action per active status', () {
      expect(TripAction.forStatus(TripStatus.accepted), TripAction.arrived);
      expect(TripAction.forStatus(TripStatus.arrived), TripAction.start);
      expect(TripAction.forStatus(TripStatus.started), TripAction.end);
    });

    test('has no action in terminal/unknown states', () {
      expect(TripAction.forStatus(TripStatus.ended), TripAction.none);
      expect(TripAction.forStatus(TripStatus.cancelled), TripAction.none);
      expect(TripAction.forStatus(TripStatus.requested), TripAction.none);
    });
  });

  group('TripStatus helpers', () {
    test('isActive covers accepted/arrived/started only', () {
      expect(TripStatus.accepted.isActive, isTrue);
      expect(TripStatus.started.isActive, isTrue);
      expect(TripStatus.ended.isActive, isFalse);
      expect(TripStatus.cancelled.isActive, isFalse);
    });

    test('isTerminal covers ended/cancelled', () {
      expect(TripStatus.ended.isTerminal, isTrue);
      expect(TripStatus.cancelled.isTerminal, isTrue);
      expect(TripStatus.started.isTerminal, isFalse);
    });
  });

  group('TripOfferController.accept', () {
    late _MockApi api;

    ProviderContainer containerWithOffer() {
      final c = ProviderContainer(
        overrides: [tripsApiProvider.overrideWithValue(api)],
      );
      addTearDown(c.dispose);
      final now = DateTime.now().toUtc();
      c
          .read(tripOfferControllerProvider.notifier)
          .present(
            TripOffer(
              offerId: 'off_1',
              rideRequestId: 'req_1',
              vehicleType: VehicleType.auto,
              pickup: const TripPlace(lat: 1, lng: 2),
              distanceMeters: 850,
              expiresAt: now.add(const Duration(seconds: 15)),
              receivedAt: now,
            ),
          );
      return c;
    }

    setUp(() => api = _MockApi());

    test('a 409 (offer gone) clears the offer', () async {
      when(() => api.acceptOffer('off_1')).thenThrow(_httpError(409));
      final c = containerWithOffer();

      await expectLater(
        c.read(tripOfferControllerProvider.notifier).accept(),
        throwsA(isA<DioException>()),
      );
      expect(c.read(tripOfferControllerProvider), isNull);
    });

    test('any other failure keeps the offer for a retry', () async {
      when(() => api.acceptOffer('off_1')).thenThrow(_httpError(500));
      final c = containerWithOffer();

      await expectLater(
        c.read(tripOfferControllerProvider.notifier).accept(),
        throwsA(isA<DioException>()),
      );
      expect(c.read(tripOfferControllerProvider)?.offerId, 'off_1');
    });
  });
}
