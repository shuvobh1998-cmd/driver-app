import 'package:dio/dio.dart';

import '../auth_token_service.dart';

/// On `401 TOKEN_EXPIRED`, refreshes the access token once (single-flight,
/// owned by [AuthTokenService]) and replays the failed request with the new
/// token. A failed refresh forces a sign-out and bubbles the error so the app
/// kicks the driver to login.
///
/// [QueuedInterceptor] serializes concurrent 401s, so a burst of expired
/// requests triggers only one refresh.
class RefreshInterceptor extends QueuedInterceptor {
  RefreshInterceptor(this._tokens);

  final AuthTokenService _tokens;

  /// The owning Dio, used to replay the original request after a refresh.
  /// Set by [ApiClient] right after the interceptor stack is assembled.
  late final Dio dio;

  static const _retriedFlag = '__refresh_retried';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final data = err.response?.data;
    final code = (data is Map && data['error'] is Map)
        ? data['error']['code'] as String?
        : null;

    final shouldRefresh =
        err.response?.statusCode == 401 &&
        code == 'TOKEN_EXPIRED' &&
        options.extra[_retriedFlag] != true;

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final refreshed = await _tokens.refresh();
    if (!refreshed) {
      _tokens.forceSignOut();
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedFlag] = true;
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
