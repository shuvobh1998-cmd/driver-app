import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../notifications/data/device_registrar.dart';
import '../../data/trip_realtime.dart';
import '../controllers/trip_offer_controller.dart';

/// Mounted once at the app root (via `MaterialApp.router`'s builder). It keeps
/// the realtime coordinator alive for the whole session and, the moment an offer
/// arrives, pushes the full-screen incoming-offer takeover over whatever screen
/// the driver is on. The offer screen pops itself when the offer is answered or
/// expires, so this gate only ever needs to push.
class TripOfferGate extends ConsumerWidget {
  const TripOfferGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the socket connected and routing events for the whole session.
    ref.watch(tripRealtimeCoordinatorProvider);
    // Register/unregister the FCM device token as auth state changes (D7).
    ref.watch(deviceRegistrarProvider);

    ref.listen(tripOfferControllerProvider, (previous, next) {
      // Only push on a fresh offer (null → offer), not on internal replacements.
      if (previous == null && next != null) {
        ref.read(routerProvider).push(Routes.tripOffer);
      }
    });

    return child;
  }
}
