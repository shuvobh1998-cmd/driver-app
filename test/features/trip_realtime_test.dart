import 'package:dio/dio.dart';
import 'package:driver_app/core/config/app_config.dart';
import 'package:driver_app/core/core_providers.dart';
import 'package:driver_app/core/network/auth_token_service.dart';
import 'package:driver_app/core/network/network_providers.dart';
import 'package:driver_app/core/storage/secure_token_store.dart';
import 'package:driver_app/core/websocket/driver_socket.dart';
import 'package:driver_app/features/auth/data/models/auth_user.dart';
import 'package:driver_app/features/auth/data/models/gender.dart';
import 'package:driver_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:driver_app/features/trips/data/trip_realtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  publicId: 'usr_1',
  phone: '+919876543210',
  roles: ['RIDER', 'DRIVER'],
  status: AccountStatus.active,
);

/// Records connects instead of opening a network socket, and hands the test
/// the callbacks the coordinator registered.
class _SpySocket extends DriverSocket {
  _SpySocket()
    : super(
        const AppConfig(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'https://x',
          wsBaseUrl: 'https://x',
        ),
      );

  int connects = 0;
  int reconnects = 0;
  String? Function()? accessToken;
  void Function()? onServerDisconnect;

  @override
  void connect({
    required String? Function() accessToken,
    void Function()? onConnect,
    void Function()? onServerDisconnect,
  }) {
    connects++;
    this.accessToken = accessToken;
    this.onServerDisconnect = onServerDisconnect;
  }

  @override
  void reconnect() => reconnects++;

  @override
  void disconnect() {}
}

class _SignedIn extends AuthController {
  @override
  AuthState build() => const AuthState.authenticated(_user);
}

/// Answers `/auth/refresh` with a fixed status: 200 rotates the tokens.
class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    status == 200
        ? '{"success":true,"data":{"accessToken":"fresh","refreshToken":"r2"}}'
        : '{"success":false,"error":{"code":"UNAUTHENTICATED"}}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

final _coordinator = Provider<TripRealtimeCoordinator>((ref) {
  final c = TripRealtimeCoordinator(ref, initialBackoff: Duration.zero)
    ..start();
  ref.onDispose(c.dispose);
  return c;
});

Future<(ProviderContainer, _SpySocket, AuthTokenService)> _setUp({
  int refreshStatus = 200,
}) async {
  final store = SecureTokenStore();
  final tokens = AuthTokenService(
    apiBaseUrl: 'https://x',
    store: store,
    refreshDio: Dio(BaseOptions(baseUrl: 'https://x'))
      ..httpClientAdapter = _RefreshAdapter(refreshStatus),
  );
  await tokens.setTokens(accessToken: 'stale', refreshToken: 'r1');
  final socket = _SpySocket();
  final c = ProviderContainer(
    overrides: [
      driverSocketProvider.overrideWithValue(socket),
      authTokenServiceProvider.overrideWithValue(tokens),
      authControllerProvider.overrideWith(_SignedIn.new),
    ],
  );
  addTearDown(c.dispose);
  c.read(_coordinator);
  return (c, socket, tokens);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('connects once on sign-in; a profile edit does not reconnect', () async {
    final (c, socket, _) = await _setUp();
    expect(socket.connects, 1);

    c.read(authControllerProvider.notifier).updateUser(_user);

    expect(socket.connects, 1);
  });

  test('a server disconnect refreshes the token, then reconnects', () async {
    final (_, socket, _) = await _setUp();
    expect(socket.accessToken!(), 'stale');

    socket.onServerDisconnect!();
    await pumpEventQueue();

    expect(socket.reconnects, 1);
    // The handshake reads the token at connect time, so it gets the new one.
    expect(socket.accessToken!(), 'fresh');
  });

  test('a rejected refresh signs out instead of reconnecting', () async {
    final (_, socket, tokens) = await _setUp(refreshStatus: 401);
    var signedOut = false;
    tokens.onForcedSignOut.listen((_) => signedOut = true);

    socket.onServerDisconnect!();
    await pumpEventQueue();

    expect(socket.reconnects, 0);
    expect(signedOut, isTrue);
  });
}
