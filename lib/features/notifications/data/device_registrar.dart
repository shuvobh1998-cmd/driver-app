import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'notifications_providers.dart';

/// Registers this device's FCM token with the backend on sign-in and clears it
/// on sign-out, so a tapped push and the trip-offer full-screen intent reach the
/// right account.
///
/// Best-effort throughout: Firebase is only configured for some flavors, so any
/// FCM failure is swallowed — push is an enhancement, not a hard dependency.
class DeviceRegistrar {
  DeviceRegistrar(this._ref);

  final Ref _ref;
  ProviderSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenSub;
  String? _lastToken;
  bool _registered = false;

  void start() {
    _authSub = _ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.isAuthenticated) {
        _register();
      } else if (prev?.isAuthenticated ?? false) {
        _unregister();
      }
    }, fireImmediately: true);
  }

  void dispose() {
    _authSub?.close();
    _tokenSub?.cancel();
  }

  static String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ANDROID',
    TargetPlatform.iOS => 'IOS',
    _ => 'WEB',
  };

  Future<void> _register() async {
    if (_registered) return;
    _registered = true;
    try {
      final push = _ref.read(pushServiceProvider);
      final token = await push.register();
      if (token == null || token.isEmpty) return;
      _lastToken = token;
      await _ref
          .read(notificationsApiProvider)
          .registerDeviceToken(fcmToken: token, platform: _platform);
      // Keep the backend in sync if the token later rotates.
      _tokenSub ??= push.onTokenRefresh.listen(_onTokenRefresh);
    } catch (_) {
      // Firebase not configured for this flavor, or the user denied permission.
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    _lastToken = token;
    try {
      await _ref
          .read(notificationsApiProvider)
          .registerDeviceToken(fcmToken: token, platform: _platform);
    } catch (_) {}
  }

  Future<void> _unregister() async {
    _registered = false;
    final token = _lastToken;
    _lastToken = null;
    if (token == null) return;
    try {
      await _ref.read(notificationsApiProvider).unregisterDeviceToken(token);
    } catch (_) {
      // The session may already be torn down — clearing the local token is
      // what matters so a new sign-in re-registers cleanly.
    }
    try {
      await _ref.read(pushServiceProvider).deleteToken();
    } catch (_) {}
  }
}

/// Always-alive registrar, mounted at the app root alongside the realtime
/// coordinators.
final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  final registrar = DeviceRegistrar(ref)..start();
  ref.onDispose(registrar.dispose);
  return registrar;
});
