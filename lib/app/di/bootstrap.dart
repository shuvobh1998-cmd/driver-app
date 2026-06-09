import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_providers.dart';
import '../app.dart';

/// Single startup path shared by every flavor entrypoint. The entrypoint passes
/// its [AppFlavor]; bootstrap builds the [AppConfig] from `--dart-define`s,
/// injects it via a [ProviderScope] override, and mounts the app.
///
/// Per-flavor side effects (Firebase init, crash reporting) hook in here later.
Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment(flavor);

  // TODO(D1+): await Firebase.initializeApp(...) per-flavor before runApp.

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const DriverApp(),
    ),
  );
}
