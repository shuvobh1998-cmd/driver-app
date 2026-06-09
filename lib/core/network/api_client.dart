import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/idempotency_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';

/// The app's single HTTP entrypoint. Wraps a configured [Dio] with the
/// interceptor stack agreed in the plan:
///   auth (token attach) → idempotency → refresh (401 retry) → error (normalize).
///
/// Interceptor *bodies* are stubs in Sprint 0; the wiring and order are final.
class ApiClient {
  ApiClient({
    required AppConfig config,
    String? Function()? accessToken,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    this.dio
      ..options.baseUrl = config.apiBaseUrl
      ..options.connectTimeout = const Duration(seconds: 15)
      ..options.receiveTimeout = const Duration(seconds: 20)
      ..options.headers['Content-Type'] = 'application/json'
      ..interceptors.addAll([
        AuthInterceptor(accessToken ?? () => null),
        IdempotencyInterceptor(),
        RefreshInterceptor(),
        const ErrorInterceptor(),
      ]);
  }

  final Dio dio;
}
