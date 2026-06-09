import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/config_providers.dart';
import 'api_client.dart';

/// The shared [ApiClient], built from the active [AppConfig]. Repositories
/// depend on this rather than constructing Dio themselves.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  // TODO(D1): pass the access-token getter from the auth controller.
  return ApiClient(config: config);
});
