import 'package:driver_app/features/onboarding_kyc/data/models/onboarding_enums.dart';
import 'package:driver_app/features/trips/data/models/trip_enums.dart';
import 'package:driver_app/features/trips/data/models/trip_offer.dart';
import 'package:driver_app/features/trips/presentation/widgets/next_action_button.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
