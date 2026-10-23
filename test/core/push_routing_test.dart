import 'package:driver_app/app/deep_links.dart';
import 'package:driver_app/app/push_router.dart';
import 'package:driver_app/core/push/push_service.dart';
import 'package:driver_app/features/trips/data/models/trip_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appRouteForDeepLink', () {
    test('maps the backend push catalog onto app routes', () {
      expect(appRouteForDeepLink('/driver/home'), '/');
      expect(appRouteForDeepLink('/driver/kyc'), '/onboarding/documents');
      expect(appRouteForDeepLink('/driver/wallet'), '/earnings/wallet');
      expect(appRouteForDeepLink('/trip/trp_1'), '/trips/trp_1');
      expect(appRouteForDeepLink('/trips/trp_1'), '/trips/trp_1');
      expect(appRouteForDeepLink('/trip/trp_1/summary'), '/trip/trp_1/summary');
      expect(appRouteForDeepLink('/carpool/trip/sch_1'), '/carpool/sch_1');
      expect(appRouteForDeepLink('/chat/usr_9'), '/chats/usr_9');
      expect(appRouteForDeepLink('/support/ticket/tkt_1'), '/support/tkt_1');
    });

    test('returns null for rider-only, offer and unknown links', () {
      expect(appRouteForDeepLink('/rider/trip/trp_1'), isNull);
      expect(appRouteForDeepLink('/carpool/booking/bkg_1'), isNull);
      expect(appRouteForDeepLink('/driver/offer/off_1'), isNull);
      expect(appRouteForDeepLink('/nope'), isNull);
      expect(appRouteForDeepLink(null), isNull);
    });
  });

  group('flattenPushData', () {
    test('decodes the stringified FCM data into a parseable offer', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 10))
          .toIso8601String();
      final data = flattenPushData({
        'type': 'TRIP_OFFERED',
        'deepLink': '/driver/offer/off_1',
        'data':
            '{"rideRequestId":"req_1","vehicleType":"AUTO",'
            '"pickup":{"lat":22.5,"lng":88.3},"expiresAt":"$expiresAt"}',
      });

      // offerId is recovered from the deep link.
      final offer = TripOffer.tryParse(data);
      expect(offer?.offerId, 'off_1');
      expect(offer?.pickup.lat, 22.5);
      expect(offer?.isExpired, isFalse);
    });

    test('keeps plain string fields as they are', () {
      final data = flattenPushData({
        'type': 'PAYOUT_PROCESSED',
        'title': 'Paid',
      });
      expect(data['title'], 'Paid');
      expect(data['offerId'], isNull);
    });
  });

  test('decodePushPayload round-trips and rejects junk', () {
    expect(decodePushPayload('{"type":"CHAT_MESSAGE"}'), {
      'type': 'CHAT_MESSAGE',
    });
    expect(decodePushPayload('not json'), isNull);
    expect(decodePushPayload(null), isNull);
  });
}
