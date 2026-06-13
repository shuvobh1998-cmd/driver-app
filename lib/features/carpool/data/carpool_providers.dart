import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import 'carpool_api.dart';
import 'chat_api.dart';
import 'models/booking.dart';
import 'models/scheduled_trip.dart';

/// Transport over the scheduled-carpool + bookings endpoints.
final carpoolApiProvider = Provider<CarpoolApi>(
  (ref) => CarpoolApi(ref.watch(apiClientProvider).dio),
);

/// Transport over the 1:1 chat endpoints.
final chatApiProvider = Provider<ChatApi>(
  (ref) => ChatApi(ref.watch(apiClientProvider).dio),
);

/// Full detail for one posted trip, cached per id. Invalidate to re-fetch.
final scheduledTripDetailProvider =
    FutureProvider.family<ScheduledTrip, String>(
      (ref, id) => ref.watch(carpoolApiProvider).detail(id),
    );

/// Bookings on one posted trip, cached per trip id. Invalidate after a no-show.
final tripBookingsProvider = FutureProvider.family<List<Booking>, String>(
  (ref, id) => ref.watch(carpoolApiProvider).tripBookings(id),
);
