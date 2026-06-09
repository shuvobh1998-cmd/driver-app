import 'package:dio/dio.dart';

/// On `401 TOKEN_EXPIRED`, refreshes the access token once and replays the
/// failed request; a failed refresh bubbles up so the app can kick to login.
///
/// Skeleton: the refresh call + single-flight lock land in D1. Today it simply
/// forwards the error so the pipeline is in place.
class RefreshInterceptor extends QueuedInterceptor {
  RefreshInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isExpired = err.response?.statusCode == 401;
    if (!isExpired) {
      handler.next(err);
      return;
    }
    // TODO(D1): POST /auth/refresh, update the token store, retry once,
    // and on failure clear the session.
    handler.next(err);
  }
}
