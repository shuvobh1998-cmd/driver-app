import 'router/app_router.dart';

/// Maps a backend `deepLink` (push payloads and inbox rows) to this app's
/// route. The backend speaks its own paths (`/driver/wallet`,
/// `/chat/:fromUserId`, …), so pushing them raw would hit no route. Returns
/// null for links with no driver screen (rider-only links, anything unknown).
/// `/driver/offer/:id` is null too: a tapped offer is re-presented from the
/// push payload, not navigated to.
String? appRouteForDeepLink(String? link) {
  if (link == null) return null;
  final segments = Uri.tryParse(
    link,
  )?.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments == null || segments.isEmpty) return null;
  return switch (segments) {
    ['driver', 'home'] => Routes.home,
    ['driver', 'kyc'] => Routes.kycDocuments,
    ['driver', 'wallet'] => Routes.wallet,
    ['trip', final id, 'summary'] ||
    ['trips', final id, 'summary'] => '/trip/$id/summary',
    ['trip', final id] || ['trips', final id] => '/trips/$id',
    ['carpool', 'trip', final id] => '/carpool/$id',
    ['chat', final userId] => '/chats/$userId',
    ['support', 'ticket', final id] => '/support/$id',
    _ => null,
  };
}
