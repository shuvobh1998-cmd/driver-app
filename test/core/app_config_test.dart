import 'package:driver_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDemoLocation', () {
    test('parses lat,lng (spaces allowed)', () {
      expect(AppConfig.parseDemoLocation('28.6315, 77.2167'), (
        lat: 28.6315,
        lng: 77.2167,
      ));
    });

    test('empty means no demo location: real GPS', () {
      expect(AppConfig.parseDemoLocation(''), isNull);
    });

    test('a malformed or out-of-range value is ignored, not used', () {
      expect(AppConfig.parseDemoLocation('28.6315'), isNull);
      expect(AppConfig.parseDemoLocation('28.6315,77.2167,1'), isNull);
      expect(AppConfig.parseDemoLocation('delhi,india'), isNull);
      // Latitude must be within ±90, longitude within ±180.
      expect(AppConfig.parseDemoLocation('128.6,77.2'), isNull);
    });
  });
}
