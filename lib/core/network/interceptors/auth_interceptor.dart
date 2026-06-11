import 'package:dio/dio.dart';

/// Attaches the in-memory access token to outgoing requests. The token source
/// is the shared `AuthTokenService`, read fresh on every request so a just-
/// refreshed token is picked up automatically on a retry.
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
