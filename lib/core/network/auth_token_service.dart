import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

/// Owns the live session tokens and the single-flight refresh.
///
/// - The **access token** lives in memory and is attached to every request by
///   the [AuthInterceptor].
/// - The **refresh token** is persisted in [SecureTokenStore] and rotated on
///   every refresh (the backend invalidates the old one).
///
/// This service deliberately knows nothing about feature models or Riverpod so
/// both the Dio interceptors and the `AuthController` can share one instance
/// without an import cycle. It refreshes over its **own** bare [Dio] so a 401
/// on `/auth/refresh` can't re-enter the interceptor stack.
class AuthTokenService {
  AuthTokenService({
    required String apiBaseUrl,
    required SecureTokenStore store,
    Dio? refreshDio,
    // A named param can't be an initializing formal (it would be private), so
    // assign in the list and silence the lint.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               baseUrl: apiBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               headers: {'Content-Type': 'application/json'},
             ),
           );

  final SecureTokenStore _store;
  final Dio _refreshDio;

  final _forcedSignOut = StreamController<void>.broadcast();

  /// Emits when a refresh fails and the session is dead — the app should route
  /// the driver back to login. The `AuthController` listens to this.
  Stream<void> get onForcedSignOut => _forcedSignOut.stream;

  String? _accessToken;
  String? get accessToken => _accessToken;

  Future<String?> readRefreshToken() => _store.readRefreshToken();

  /// Persists a freshly-issued session (after login / signup / refresh).
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    await _store.writeRefreshToken(refreshToken);
  }

  /// Clears the session locally (used on explicit logout).
  Future<void> clear() async {
    _accessToken = null;
    await _store.clear();
  }

  Future<bool>? _inflight;

  /// Refreshes the access token, coalescing concurrent callers into one network
  /// call. Returns `true` on success (tokens rotated), `false` when there is no
  /// refresh token or the backend rejects it.
  Future<bool> refresh() => _inflight ??= _refresh().whenComplete(() {
    _inflight = null;
  });

  Future<bool> _refresh() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : data as Map;
      final access = payload['accessToken'] as String?;
      final refresh = payload['refreshToken'] as String?;
      if (access == null || refresh == null) return false;
      await setTokens(accessToken: access, refreshToken: refresh);
      return true;
    } on DioException {
      return false;
    }
  }

  /// Wipes the session and notifies listeners that the user was signed out.
  void forceSignOut() {
    _accessToken = null;
    unawaited(_store.clear());
    if (!_forcedSignOut.isClosed) _forcedSignOut.add(null);
  }

  void dispose() => _forcedSignOut.close();
}
