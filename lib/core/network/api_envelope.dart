import 'package:dio/dio.dart';

import '../error/app_failure.dart';
import '../error/error_messages.dart';

/// Every backend response is wrapped in a standard envelope:
///
/// ```json
/// { "success": true,  "data": { ... },              "meta": { ... } }
/// { "success": false, "error": { "code", "message", "field" }, "meta": { ... } }
/// ```
///
/// Repositories never touch [Response.data] directly — they call [unwrap] /
/// [unwrapList] so the `data` payload is extracted (and a malformed envelope
/// surfaces as an [AppFailure] rather than a random cast error).
extension ApiEnvelope on Response<dynamic> {
  /// Pulls the `data` object out of a success envelope and maps it with [fromJson].
  T unwrap<T>(T Function(Map<String, dynamic> json) fromJson) {
    final data = _data();
    if (data is! Map<String, dynamic>) {
      throw const AppFailure(
        code: AppFailure.unknownCode,
        message: 'Unexpected response from the server.',
      );
    }
    return fromJson(data);
  }

  /// Pulls a `data` array out of a success envelope and maps each element.
  List<T> unwrapList<T>(T Function(Map<String, dynamic> json) fromJson) {
    final data = _data();
    if (data is! List) {
      throw const AppFailure(
        code: AppFailure.unknownCode,
        message: 'Unexpected response from the server.',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  Object? _data() {
    final body = data;
    if (body is Map<String, dynamic>) return body['data'];
    return body;
  }
}

/// Resolves an [AppFailure] from a raw error envelope map, used where we read
/// the code before the [ErrorInterceptor] has normalized the exception
/// (e.g. inside the refresh single-flight, which runs on a bare Dio).
AppFailure failureFromEnvelope(Object? body, {int? statusCode}) {
  final code = (body is Map && body['error'] is Map)
      ? (body['error']['code'] as String?) ?? AppFailure.unknownCode
      : AppFailure.unknownCode;
  return AppFailure(
    code: code,
    message: errorMessageFor(code),
    statusCode: statusCode,
  );
}
