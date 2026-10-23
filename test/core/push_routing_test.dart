import 'package:driver_app/app/deep_links.dart';
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
}
