import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Exposes the active [AppConfig] to the widget tree. The real value is
/// injected at startup via a [ProviderScope] override in `app/di/bootstrap`,
/// so the entrypoint flavor decides the config and the rest of the app just
/// reads it.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in main_<flavor>.dart',
  ),
);
