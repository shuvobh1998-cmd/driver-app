import '../config/app_config.dart';

/// Headers the backend expects on every request (REST and the token refresh).
/// A build below the platform minimum gets `426 FORCE_UPDATE_REQUIRED`.
Map<String, String> appRequestHeaders() => {
  'X-App-Version': kAppVersion,
  'X-App-Platform': appPlatform,
};

/// Connect + receive timeout for every call. The dev backend sleeps when idle
/// and its first answer can take up to ~60 s while it wakes.
const Duration kApiTimeout = Duration(seconds: 60);
