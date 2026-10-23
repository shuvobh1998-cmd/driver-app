import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_envelope.dart';
import '../network/network_providers.dart';
import 'app_config.dart';
import 'app_remote_config.dart';

/// Fetches `GET /app/config` (force-update flag, support contacts, legal links).
/// Cached for 6 h, then re-fetched so a driver who stays online all day still
/// picks up a new minimum / latest version.
final appRemoteConfigProvider = FutureProvider<AppRemoteConfig>((ref) async {
  final refresh = Timer(const Duration(hours: 6), ref.invalidateSelf);
  ref.onDispose(refresh.cancel);
  final dio = ref.watch(apiClientProvider).dio;
  final Response<dynamic> res = await dio.get<dynamic>('/app/config');
  return res.unwrap(AppRemoteConfig.fromJson);
});

/// True when the running build is older than the platform's minimum supported
/// version, or the backend has flipped the hard `forceUpdate` flag.
bool isUpdateRequired(
  AppRemoteConfig config, {
  String current = kAppVersion,
  String? platform,
}) {
  if (config.forceUpdate) return true;
  final min = (platform ?? appPlatform) == 'ios'
      ? config.minSupportedVersion.ios
      : config.minSupportedVersion.android;
  if (min == null || min.isEmpty) return false;
  return compareSemver(current, min) < 0;
}

/// True when the platform's `latestVersion` is newer than the running build —
/// an optional update, offered without blocking (see [isUpdateRequired] for
/// the blocking case).
bool isUpdateAvailable(
  AppRemoteConfig config, {
  String current = kAppVersion,
  String? platform,
}) {
  final latest = (platform ?? appPlatform) == 'ios'
      ? config.latestVersion.ios
      : config.latestVersion.android;
  if (latest == null || latest.isEmpty) return false;
  return compareSemver(current, latest) < 0;
}

/// Whether to show the optional "new version available" hint: a newer build
/// exists and the driver hasn't dismissed the hint this session.
class OptionalUpdateNotice extends Notifier<bool> {
  @override
  bool build() {
    final config = ref.watch(appRemoteConfigProvider).value;
    return config != null && isUpdateAvailable(config);
  }

  void dismiss() => state = false;
}

final optionalUpdateNoticeProvider =
    NotifierProvider<OptionalUpdateNotice, bool>(OptionalUpdateNotice.new);

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
