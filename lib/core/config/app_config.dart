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
  });

  final AppFlavor flavor;

  /// REST base URL, e.g. `https://api.dev.example.com`.
  final String apiBaseUrl;

  /// Socket.IO base URL (the `/driver` namespace is appended by the client).
  final String wsBaseUrl;

  bool get isProd => flavor == AppFlavor.prod;

  /// Builds config from `--dart-define`s, defaulting to the given [flavor].
  /// Each flavor entrypoint calls this with its own default so a bare
  /// `flutter run -t lib/main_dev.dart` still has a sane API base.
  factory AppConfig.fromEnvironment(AppFlavor flavor) {
    const apiBase = String.fromEnvironment('API_BASE_URL');
    const wsBase = String.fromEnvironment('WS_BASE_URL');
    final defaults = _defaultsFor(flavor);
    return AppConfig(
      flavor: flavor,
      apiBaseUrl: apiBase.isEmpty ? defaults.$1 : apiBase,
      wsBaseUrl: wsBase.isEmpty ? defaults.$2 : wsBase,
    );
  }

  /// (apiBaseUrl, wsBaseUrl) fallbacks per flavor. Replace with real hosts.
  static (String, String) _defaultsFor(AppFlavor flavor) => switch (flavor) {
    AppFlavor.dev => (
      'https://api.dev.driverapp.example.com',
      'https://ws.dev.driverapp.example.com',
    ),
    AppFlavor.staging => (
      'https://api.staging.driverapp.example.com',
      'https://ws.staging.driverapp.example.com',
    ),
    AppFlavor.prod => (
      'https://api.driverapp.example.com',
      'https://ws.driverapp.example.com',
    ),
  };
}
