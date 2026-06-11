import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'auth_token_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/idempotency_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';

/// The app's single HTTP entrypoint. Wraps a configured [Dio] with the
/// interceptor stack agreed in the plan:
///   auth (token attach) → idempotency → refresh (401 retry) → error (normalize).
class ApiClient {
  ApiClient({
    required AppConfig config,
    required AuthTokenService tokenService,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    final refresh = RefreshInterceptor(tokenService);
    this.dio
      ..options.baseUrl = config.apiBaseUrl
      ..options.connectTimeout = const Duration(seconds: 15)
      ..options.receiveTimeout = const Duration(seconds: 20)
      ..options.headers['Content-Type'] = 'application/json'
      ..interceptors.addAll([
        AuthInterceptor(() => tokenService.accessToken),
        IdempotencyInterceptor(),
        refresh,
        const ErrorInterceptor(),
      ]);
    // The refresh interceptor replays the original request on the same client.
    refresh.dio = this.dio;
  }

  final Dio dio;
}
