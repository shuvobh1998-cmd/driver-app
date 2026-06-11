import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_providers.dart';
import '../../features/auth/data/firebase_phone_verifier.dart';
import '../../features/auth/data/phone_verifier.dart';
import '../app.dart';

/// Single startup path shared by every flavor entrypoint. The entrypoint passes
/// its [AppFlavor]; bootstrap builds the [AppConfig] from `--dart-define`s,
/// initializes Firebase (when configured for the flavor), injects provider
/// overrides, and mounts the app.
Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment(flavor);

  final overrides = [appConfigProvider.overrideWithValue(config)];

  // Firebase powers client-side phone OTP. Only the dev flavor is registered
  // today, so init is best-effort: if it fails (flavor without a Firebase
  // config), we keep the gated UnconfiguredPhoneVerifier instead of crashing.
  try {
    await Firebase.initializeApp();
    overrides.add(
      phoneVerifierProvider.overrideWithValue(FirebasePhoneVerifier()),
    );
  } catch (_) {
    // Phone OTP stays gated; password login is unaffected.
  }

  runApp(ProviderScope(overrides: overrides, child: const DriverApp()));
}
