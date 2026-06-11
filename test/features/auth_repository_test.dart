import 'package:dio/dio.dart';
import 'package:driver_app/core/network/auth_token_service.dart';
import 'package:driver_app/core/storage/secure_token_store.dart';
import 'package:driver_app/features/auth/data/auth_api.dart';
import 'package:driver_app/features/auth/data/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canned-response adapter so the repository runs without a network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('login persists rotated tokens and returns the user', () async {
    const payload =
        '{"success":true,"data":{'
        '"accessToken":"acc","refreshToken":"ref","expiresIn":900,'
        '"user":{"publicId":"usr_1","phone":"+919876543210",'
        '"roles":["DRIVER"],"status":"ACTIVE","firstName":"Asha"}}}';

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StubAdapter(payload);
    final store = SecureTokenStore();
    final tokens = AuthTokenService(
      apiBaseUrl: 'https://example.test',
      store: store,
      refreshDio: dio,
    );
    final repo = AuthRepository(api: AuthApi(dio), tokens: tokens);

    final user = await repo.login(phone: '+919876543210', password: '654321');

    expect(user.publicId, 'usr_1');
    expect(user.displayName, 'Asha');
    expect(user.isDriver, isTrue);
    expect(tokens.accessToken, 'acc');
    expect(await store.readRefreshToken(), 'ref');
  });

  test('restoreSession returns null when no token is stored', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StubAdapter('{}');
    final tokens = AuthTokenService(
      apiBaseUrl: 'https://example.test',
      store: SecureTokenStore(),
      refreshDio: dio,
    );
    final repo = AuthRepository(api: AuthApi(dio), tokens: tokens);

    expect(await repo.restoreSession(), isNull);
  });
}
