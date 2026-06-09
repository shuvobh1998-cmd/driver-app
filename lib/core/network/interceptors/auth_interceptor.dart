import 'package:dio/dio.dart';

/// Attaches the in-memory access token to outgoing requests.
///
/// Skeleton: the token source wires in with `AuthController` in D1. For now it
/// is a no-op placeholder so the client assembles cleanly.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._accessToken);

  /// Returns the current access token, or null when signed out.
  final String? Function() _accessToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _accessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
