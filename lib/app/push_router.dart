import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core_providers.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/trips/data/models/trip_offer.dart';
import '../features/trips/presentation/controllers/trip_offer_controller.dart';
import 'deep_links.dart';
import 'router/app_router.dart';

/// Routes a tapped push — OS-shown FCM or the local notification shown for a
/// data-only message — to the screen its `deepLink` names.
///
/// A cold start from a tap lands on the splash first, so the tap is held until
/// the session is restored. A `TRIP_OFFERED` tap re-presents the offer from
/// the push payload (there's no REST endpoint to fetch a pending offer); one
/// that has already expired is dropped.
class PushRouter {
  PushRouter(this._ref);

  final Ref _ref;
  StreamSubscription<RemoteMessage>? _openedSub;
  ProviderSubscription<AuthState>? _authSub;
  Map<String, dynamic>? _pending;

  Future<void> start() async {
    _authSub = _ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.isAuthenticated) _flush();
    });
    try {
      final push = _ref.read(pushServiceProvider);
      _openedSub = push.onMessageOpenedApp.listen((m) => _onTap(m.data));
      final launchedByLocal = await push.initLocalTaps(_onTap);
      final launch = (await push.initialMessage())?.data ?? launchedByLocal;
      if (launch != null) _onTap(launch);
    } catch (_) {
      // Firebase isn't configured for this flavor — there are no pushes.
    }
  }

  void dispose() {
    _authSub?.close();
    _openedSub?.cancel();
  }

  void _onTap(Map<String, dynamic> data) {
    _pending = data;
    if (_ref.read(authControllerProvider).isAuthenticated) _flush();
  }

  void _flush() {
    final data = _pending;
    if (data == null) return;
    _pending = null;
    // After a sign-in the router first settles on home; open on top of it.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _open(flattenPushData(data)))
      ..ensureVisualUpdate();
  }

  void _open(Map<String, dynamic> data) {
    if (data['type'] == 'TRIP_OFFERED') {
      final offer = TripOffer.tryParse(data);
      if (offer != null && !offer.isExpired) {
        _ref.read(tripOfferControllerProvider.notifier).present(offer);
      }
      return;
    }
    final route = appRouteForDeepLink(data['deepLink'] as String?);
    if (route != null) _ref.read(routerProvider).push(route);
  }
}

/// FCM data values are all strings, so the contract's nested `data` (and any
/// object inside it, like an offer's `pickup`) arrives JSON-encoded. Decodes
/// those and lifts the nested `data` fields to the top level. A missing
/// `offerId` is taken from an offer deep link (`/driver/offer/:id`).
Map<String, dynamic> flattenPushData(Map<String, dynamic> raw) {
  Object? decode(Object? v) {
    if (v is String && (v.startsWith('{') || v.startsWith('['))) {
      try {
        return jsonDecode(v);
      } on FormatException {
        return v;
      }
    }
    return v;
  }

  final out = {for (final e in raw.entries) e.key: decode(e.value)};
  final nested = out['data'];
  if (nested is Map) {
    for (final e in nested.entries) {
      out.putIfAbsent('${e.key}', () => decode(e.value));
    }
  }
  final link = out['deepLink'];
  if (out['offerId'] == null && link is String) {
    final segments = Uri.tryParse(link)?.pathSegments ?? const [];
    if (segments.length == 3 && segments[1] == 'offer') {
      out['offerId'] = segments[2];
    }
  }
  return out;
}

/// Always-alive push router, mounted at the app root.
final pushRouterProvider = Provider<PushRouter>((ref) {
  final router = PushRouter(ref);
  unawaited(router.start());
  ref.onDispose(router.dispose);
  return router;
});
