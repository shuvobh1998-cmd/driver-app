import 'package:dio/dio.dart';
import 'package:driver_app/core/config/app_config.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/core/network/auth_token_service.dart';
import 'package:driver_app/core/storage/secure_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = AppConfig(
  flavor: AppFlavor.dev,
  apiBaseUrl: 'https://example.test',
  wsBaseUrl: 'https://example.test',
);

/// Replies with one canned envelope and records the last request.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, this.statusCode);
  final String body;
  final int statusCode;
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
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuthTokenService _tokens(SecureTokenStore store, HttpClientAdapter refresh) =>
    AuthTokenService(
      apiBaseUrl: _config.apiBaseUrl,
      store: store,
      refreshDio: Dio(BaseOptions(baseUrl: _config.apiBaseUrl))
        ..httpClientAdapter = refresh,
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('every request carries the app version and platform', () async {
    final adapter = _StubAdapter('{"success":true,"data":{}}', 200);
    final client = ApiClient(
      config: _config,
      tokenService: _tokens(SecureTokenStore(), adapter),
      dio: Dio()..httpClientAdapter = adapter,
    );

    await client.dio.get<dynamic>('/drivers/me/state');

    final headers = adapter.lastRequest!.headers;
    expect(headers['X-App-Version'], kAppVersion);
    expect(headers['X-App-Platform'], 'android');
  });
}
