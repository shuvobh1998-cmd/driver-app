import 'package:dio/dio.dart';
import 'package:driver_app/core/network/auth_token_service.dart';
import 'package:driver_app/core/storage/secure_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Dio whose adapter returns canned responses, so the refresh path is
/// exercised without real network.
Dio _stubDio(RequestOptions Function()? onRequest, ResponseBody response) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _StubAdapter(response);
  return dio;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._response);
  final ResponseBody _response;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return _response;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('refresh rotates tokens from the response envelope', () async {
    final store = SecureTokenStore();
    await store.writeRefreshToken('old-refresh');

    final adapter = _StubAdapter(
      ResponseBody.fromString(
        '{"success":true,"data":{"accessToken":"new-access",'
        '"refreshToken":"new-refresh","expiresIn":900}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    final service = AuthTokenService(
      apiBaseUrl: 'https://example.test',
      store: store,
      refreshDio: dio,
    );

    final ok = await service.refresh();

    expect(ok, isTrue);
    expect(service.accessToken, 'new-access');
    expect(await store.readRefreshToken(), 'new-refresh');
  });

  test('refresh returns false when there is no stored token', () async {
    final service = AuthTokenService(
      apiBaseUrl: 'https://example.test',
      store: SecureTokenStore(),
      refreshDio: _stubDio(null, ResponseBody.fromString('{}', 200)),
    );
    expect(await service.refresh(), isFalse);
  });

  test('forceSignOut clears the access token and emits an event', () async {
    final store = SecureTokenStore();
    await store.writeRefreshToken('r');
    final service = AuthTokenService(
      apiBaseUrl: 'https://example.test',
      store: store,
      refreshDio: _stubDio(null, ResponseBody.fromString('{}', 200)),
    );
    await service.setTokens(accessToken: 'a', refreshToken: 'r');

    final signedOut = expectLater(service.onForcedSignOut, emits(null));
    service.forceSignOut();
    await signedOut;

    expect(service.accessToken, isNull);
  });
}
