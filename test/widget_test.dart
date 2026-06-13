import 'package:driver_app/app/app.dart';
import 'package:driver_app/core/config/app_config.dart';
import 'package:driver_app/core/config/app_remote_config.dart';
import 'package:driver_app/core/config/config_providers.dart';
import 'package:driver_app/core/config/remote_config_providers.dart';
import 'package:driver_app/core/storage/app_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _pumpApp(WidgetTester tester, {required bool introSeen}) async {
  SharedPreferences.setMockInitialValues(
    introSeen ? {'onboarding_seen_v1': true} : {},
  );
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromEnvironment(AppFlavor.dev),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Avoid hitting the network for the force-update gate.
        appRemoteConfigProvider.overrideWith((ref) async => _fakeConfig()),
      ],
      child: const DriverApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // No secure-storage platform channel in widget tests.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('first launch shows the intro tour', (tester) async {
    await _pumpApp(tester, introSeen: false);

    // A brand-new user (no session, intro unseen) lands on the welcome tour:
    // the first slide, with Skip + Next controls.
    expect(find.text('Drive & earn'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('unauthenticated launch lands on the login screen', (
    tester,
  ) async {
    await _pumpApp(tester, introSeen: true);

    // With the intro seen and no stored session, the guard routes to login.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
