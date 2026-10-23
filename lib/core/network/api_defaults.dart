import '../config/app_config.dart';

/// Headers the backend expects on every request (REST and the token refresh).
/// A build below the platform minimum gets `426 FORCE_UPDATE_REQUIRED`.
Map<String, String> appRequestHeaders() => {
  'X-App-Version': kAppVersion,
  'X-App-Platform': appPlatform,
};
