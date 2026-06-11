import 'package:driver_app/app/app.dart';
import 'package:driver_app/core/config/app_config.dart';
import 'package:driver_app/core/config/app_remote_config.dart';
import 'package:driver_app/core/config/config_providers.dart';
import 'package:driver_app/core/config/remote_config_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

AppRemoteConfig _fakeConfig() => const AppRemoteConfig(
  vehicleTypes: [],
  supportPhone: '+910000000000',
  supportEmail: 'support@example.com',
  supportHours: '9-9',
  termsUrl: 'https://example.com/terms',
  privacyUrl: 'https://example.com/privacy',
  driverAgreementUrl: 'https://example.com/agreement',
  city: 'Kolkata',
  currency: 'INR',
  languages: ['en'],
  minSupportedVersion: AppVersion(android: '1.0.0', ios: '1.0.0'),
  latestVersion: AppVersion(android: '1.0.0', ios: '1.0.0'),
  forceUpdate: false,
);

void main() {
  setUp(() {
    // No secure-storage platform channel in widget tests.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('unauthenticated launch lands on the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppFlavor.dev),
          ),
          // Avoid hitting the network for the force-update gate.
          appRemoteConfigProvider.overrideWith((ref) async => _fakeConfig()),
        ],
        child: const DriverApp(),
      ),
    );
    await tester.pumpAndSettle();

    // With no stored session, the guard routes to login.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
