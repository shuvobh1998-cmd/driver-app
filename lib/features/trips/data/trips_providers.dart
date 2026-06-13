import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import 'models/trip.dart';
import 'trips_api.dart';

/// Transport over the trip-offer + lifecycle endpoints.
final tripsApiProvider = Provider<TripsApi>(
  (ref) => TripsApi(ref.watch(apiClientProvider).dio),
);

/// Full trip detail by public id (history detail, summary fallback). Cached per
/// id by Riverpod; invalidate to re-fetch.
final tripDetailProvider = FutureProvider.family<Trip, String>(
  (ref, tripId) => ref.watch(tripsApiProvider).tripDetail(tripId),
);
