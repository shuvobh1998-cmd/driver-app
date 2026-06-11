import 'package:dio/dio.dart';

import '../../error/app_failure.dart';
import '../../error/error_messages.dart';

/// Normalizes every transport/HTTP error into an [AppFailure] carrying the
/// backend `error.code`, so callers branch on a code and render a mapped
/// message — never raw Dio/exception text.
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = _toFailure(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: failure,
      ),
    );
  }

  AppFailure _toFailure(DioException err) {
    // Connectivity / timeout cases map to synthetic codes.
    final transportCode = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'TIMEOUT',
      DioExceptionType.connectionError => 'NETWORK',
      _ => null,
    };
    if (transportCode != null) {
      return AppFailure(
        code: transportCode,
        message: errorMessageFor(transportCode),
      );
    }

    // Backend error envelope: { "error": { "code": "...", "message": "..." } }.
    final data = err.response?.data;
    final error = (data is Map && data['error'] is Map) ? data['error'] : null;
    final code = (error?['code'] as String?) ?? AppFailure.unknownCode;
    final serverMessage = error?['message'] as String?;

    return AppFailure(
      code: code,
      message: resolveErrorMessage(code, serverMessage),
      statusCode: err.response?.statusCode,
      serverMessage: serverMessage,
    );
  }
}
