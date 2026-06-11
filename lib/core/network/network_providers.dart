import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/config_providers.dart';
import '../core_providers.dart';
import 'api_client.dart';
import 'auth_token_service.dart';

/// Holds the live session tokens and the single-flight refresh. Shared by the
/// Dio interceptor stack (via [apiClientProvider]) and the `AuthController`.
final authTokenServiceProvider = Provider<AuthTokenService>((ref) {
  final config = ref.watch(appConfigProvider);
  final service = AuthTokenService(
    apiBaseUrl: config.apiBaseUrl,
    store: ref.watch(secureTokenStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The shared [ApiClient], built from the active [AppConfig] and wired to the
/// [authTokenServiceProvider] so every request carries the access token and
/// transparently refreshes on `TOKEN_EXPIRED`.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenService: ref.watch(authTokenServiceProvider),
  );
});
