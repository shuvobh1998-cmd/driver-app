import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import 'content_api.dart';
import 'models/content_item.dart';
import 'models/support.dart';
import 'notifications_api.dart';
import 'safety_api.dart';
import 'support_api.dart';

/// Transport over the notification inbox + device-token endpoints.
final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(apiClientProvider).dio),
);

/// Transport over the trip safety (SOS + share) endpoints.
final safetyApiProvider = Provider<SafetyApi>(
  (ref) => SafetyApi(ref.watch(apiClientProvider).dio),
);

/// Transport over the support-ticket endpoints.
final supportApiProvider = Provider<SupportApi>(
  (ref) => SupportApi(ref.watch(apiClientProvider).dio),
);

/// Transport over the public CMS endpoints.
final contentApiProvider = Provider<ContentApi>(
  (ref) => ContentApi(ref.watch(apiClientProvider).dio),
);

/// Active share links for a trip, cached per trip id. Invalidate after create
/// or revoke.
final tripSharesProvider = FutureProvider.family(
  (ref, String tripId) => ref.watch(safetyApiProvider).shares(tripId),
);

/// One ticket with its thread, cached per id. Invalidate after a reply.
final ticketDetailProvider = FutureProvider.family<Ticket, String>(
  (ref, id) => ref.watch(supportApiProvider).ticket(id),
);

/// FAQ entries (uses the backend default locale; the app's locale is applied
/// server-side from the bearer where available).
final faqProvider = FutureProvider<List<ContentItem>>(
  (ref) => ref.watch(contentApiProvider).faq(),
);

/// A legal document by slug (terms, privacy, …).
final legalProvider = FutureProvider.family<ContentItem, String>(
  (ref, slug) => ref.watch(contentApiProvider).legal(slug),
);
