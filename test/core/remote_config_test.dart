import 'package:driver_app/core/config/app_remote_config.dart';
import 'package:driver_app/core/config/remote_config_providers.dart';
import 'package:flutter_test/flutter_test.dart';

AppRemoteConfig _config({
  String? android,
  String? ios,
  String? latestAndroid,
  bool force = false,
}) => AppRemoteConfig(
  vehicleTypes: const [],
  supportPhone: '',
  supportEmail: '',
  supportHours: '',
  termsUrl: '',
  privacyUrl: '',
  driverAgreementUrl: '',
  city: 'Kolkata',
  currency: 'INR',
  languages: const ['en'],
  minSupportedVersion: AppVersion(android: android, ios: ios),
  latestVersion: AppVersion(android: latestAndroid),
  forceUpdate: force,
);

void main() {
  test('compares against the running platform\'s minimum', () {
    final config = _config(android: '1.0.0', ios: '1.2.0');

    expect(
      isUpdateRequired(config, current: '1.1.0', platform: 'android'),
      isFalse,
    );
    expect(isUpdateRequired(config, current: '1.1.0', platform: 'ios'), isTrue);
  });

  test('the forceUpdate flag wins regardless of version', () {
    expect(isUpdateRequired(_config(force: true), current: '9.9.9'), isTrue);
  });

  test('a newer latestVersion is offered without blocking', () {
    final config = _config(android: '1.0.0', latestAndroid: '1.1.0');

    expect(
      isUpdateRequired(config, current: '1.0.0', platform: 'android'),
      isFalse,
    );
    expect(
      isUpdateAvailable(config, current: '1.0.0', platform: 'android'),
      isTrue,
    );
    expect(
      isUpdateAvailable(config, current: '1.1.0', platform: 'android'),
      isFalse,
    );
  });
}
