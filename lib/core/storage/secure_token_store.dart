import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the **refresh token only** in OS-backed secure storage. The access
/// token lives in memory (held by the auth controller), never on disk.
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'refresh_token';

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshKey);
}
