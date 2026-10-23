import 'package:dio/dio.dart';
import 'package:driver_app/features/settings/data/user_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the last request and replies with a canned envelope.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('requestDataExport posts and parses the download link', () async {
    final adapter = _StubAdapter(
      '{"success":true,"data":{"url":"https://files.test/export.json",'
      '"sizeBytes":49152,"expiresAt":"2026-10-25T10:00:00.000Z"}}',
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    final export = await UserApi(dio).requestDataExport();

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/users/me/account/data-export');
    expect(export.url, 'https://files.test/export.json');
    expect(export.sizeLabel, '48 KB');
    expect(export.expiresAt, DateTime.utc(2026, 10, 25, 10));
  });
}
