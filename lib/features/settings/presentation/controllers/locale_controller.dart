import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Drives the app's active locale. `null` means "follow the OS". The choice is
/// persisted locally so it survives restarts, and mirrored to the backend
/// preferences (best-effort) by the settings screen.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'app_locale';
  static const supported = ['en', 'bn', 'hi'];

  final _storage = const FlutterSecureStorage();

  @override
  Locale? build() {
    // Load the persisted choice asynchronously; null until it resolves.
    _load();
    return null;
  }

  Future<void> _load() async {
    final code = await _storage.read(key: _key);
    if (code != null && supported.contains(code)) {
      state = Locale(code);
    }
  }

  /// Sets the locale (or clears it to follow the OS when [code] is null).
  Future<void> set(String? code) async {
    if (code == null) {
      state = null;
      await _storage.delete(key: _key);
      return;
    }
    if (!supported.contains(code)) return;
    state = Locale(code);
    await _storage.write(key: _key, value: code);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
