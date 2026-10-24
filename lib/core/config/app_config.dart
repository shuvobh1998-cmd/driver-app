import 'package:flutter/foundation.dart';

/// Current build's marketing version, sent as `X-App-Version` (strict `x.y.z`)
/// and compared against `/app/config`'s `minSupportedVersion`. Keep it in step
/// with the part of `pubspec.yaml`'s `version` before the `+`.
const String kAppVersion = '1.0.0';

/// The platform the backend keys app versions by: the `X-App-Platform` header
/// and the `android` / `ios` fields of `/app/config`'s version objects.
String get appPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

/// The build flavor. Selected by the entrypoint (`main_dev` / `main_staging`
/// / `main_prod`) and surfaced through [AppConfig].
enum AppFlavor { dev, staging, prod }

/// Immutable, build-time configuration. Values come from `--dart-define`
/// so the same source builds against dev / staging / prod without code edits.
///
/// ```sh
/// flutter run \
///   --dart-define=ENV=dev \
///   --dart-define=API_BASE_URL=https://api.dev.example.com \
///   -t lib/main_dev.dart
/// ```
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.demoLocation,
  });

  final AppFlavor flavor;

  /// REST base URL, e.g. `https://api.dev.example.com`.
  final String apiBaseUrl;

  /// Socket.IO base URL — the gateway host root (no namespace, no `/api/v1`),
  /// per the locked realtime contract.
  final String wsBaseUrl;

  /// Demo builds only: a fixed point the driver reports instead of GPS, so a
  /// tester anywhere can appear online in the city being demoed (riders match
  /// drivers within ~5 km of pickup). From
  /// `--dart-define=DEMO_LOCATION=28.6315,77.2167`; never honored in prod.
  final ({double lat, double lng})? demoLocation;

  bool get isProd => flavor == AppFlavor.prod;

  /// Builds config from `--dart-define`s, defaulting to the given [flavor].
  /// Each flavor entrypoint calls this with its own default so a bare
  /// `flutter run -t lib/main_dev.dart` still has a sane API base.
  factory AppConfig.fromEnvironment(AppFlavor flavor) {
    const apiBase = String.fromEnvironment('API_BASE_URL');
    const wsBase = String.fromEnvironment('WS_BASE_URL');
    const demo = String.fromEnvironment('DEMO_LOCATION');
    final defaults = _defaultsFor(flavor);
    return AppConfig(
      flavor: flavor,
      apiBaseUrl: apiBase.isEmpty ? defaults.$1 : apiBase,
      wsBaseUrl: wsBase.isEmpty ? defaults.$2 : wsBase,
      demoLocation: flavor == AppFlavor.prod ? null : parseDemoLocation(demo),
    );
  }

  /// Parses `lat,lng` (e.g. `28.6315,77.2167`); null when empty, malformed or
  /// out of range, so a typo falls back to real GPS rather than a bogus point.
  static ({double lat, double lng})? parseDemoLocation(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return (lat: lat, lng: lng);
  }

  /// (apiBaseUrl, wsBaseUrl) fallbacks per flavor. `dev` points at the deployed
  /// Render backend; staging/prod stay as placeholders until those hosts exist.
  /// The REST base includes the `/api/v1` prefix every endpoint sits under.
  static (String, String) _defaultsFor(AppFlavor flavor) => switch (flavor) {
    AppFlavor.dev => (
      'https://ride-sharing-backend-dev.onrender.com/api/v1',
      'https://ride-sharing-backend-dev.onrender.com',
    ),
    AppFlavor.staging => (
      'https://api.staging.driverapp.example.com/api/v1',
      'https://ws.staging.driverapp.example.com',
    ),
    AppFlavor.prod => (
      'https://api.driverapp.example.com/api/v1',
      'https://ws.driverapp.example.com',
    ),
  };
}
