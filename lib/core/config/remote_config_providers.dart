import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_envelope.dart';
import '../network/network_providers.dart';
import 'app_remote_config.dart';

/// Current build's marketing version. Hard-coded for now; swap to
/// `package_info_plus` when a single source of truth is wired in D7.
const String kAppVersion = '1.0.0';

/// Fetches `GET /app/config` (force-update flag, support contacts, legal links).
final appRemoteConfigProvider = FutureProvider<AppRemoteConfig>((ref) async {
  final dio = ref.watch(apiClientProvider).dio;
  final Response<dynamic> res = await dio.get<dynamic>('/app/config');
  return res.unwrap(AppRemoteConfig.fromJson);
});

/// True when the running build is older than the platform's minimum supported
/// version, or the backend has flipped the hard `forceUpdate` flag.
bool isUpdateRequired(AppRemoteConfig config, {String current = kAppVersion}) {
  if (config.forceUpdate) return true;
  final min = config.minSupportedVersion.android;
  if (min == null || min.isEmpty) return false;
  return compareSemver(current, min) < 0;
}

/// Compares dotted numeric versions. Returns <0, 0, >0 like [Comparable].
int compareSemver(String a, String b) {
  final pa = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pb = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
