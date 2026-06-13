import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/trip.dart';
import '../../data/models/trip_offer.dart';
import '../../data/trips_providers.dart';
import 'active_trip_controller.dart';

/// Holds the single pending [TripOffer] (or null). The realtime coordinator
/// calls [present] when `trip.offered` arrives; the incoming-offer screen reads
/// this and drives accept / decline. There is only ever one live offer — a new
/// one replaces an unanswered previous one.
class TripOfferController extends Notifier<TripOffer?> {
  @override
  TripOffer? build() => null;

  /// Surfaces a freshly-received offer. A still-valid existing offer is kept;
  /// otherwise the new one takes over.
  void present(TripOffer offer) {
    final existing = state;
    if (existing != null && !existing.isExpired) return;
    state = offer;
  }

  /// Dismisses the current offer (expiry, or after it has been answered).
  void clear() => state = null;

  /// Accepts the pending offer. On success the active trip is loaded from REST
  /// (the source of truth) and the offer is cleared. Throws on failure with the
  /// offer left in place so the screen can show the error and retry.
  Future<AcceptOfferResult> accept() async {
    final offer = state;
    if (offer == null) {
      throw StateError('No pending offer to accept.');
    }
    final result = await ref.read(tripsApiProvider).acceptOffer(offer.offerId);
    await ref.read(activeTripControllerProvider.notifier).loadCurrent();
    state = null;
    return result;
  }

  /// Declines the pending offer. Clears it immediately (the driver is done with
  /// it) and best-effort notifies the backend so matching can re-assign.
  Future<void> decline() async {
    final offer = state;
    if (offer == null) return;
    state = null;
    try {
      await ref.read(tripsApiProvider).declineOffer(offer.offerId);
    } catch (_) {
      // Decline is fire-and-forget; the offer expires server-side regardless.
    }
  }
}

final tripOfferControllerProvider =
    NotifierProvider<TripOfferController, TripOffer?>(TripOfferController.new);
