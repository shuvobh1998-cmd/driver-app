# trips

D4 — Trip lifecycle: full-screen offer, accept/decline, arrived → start(OTP) → end,
ratings, history.

## Flow

1. The realtime coordinator ([data/trip_realtime.dart](data/trip_realtime.dart))
   connects the socket on sign-in and routes `trip.*` events. `trip.offered` →
   the offer gate pushes the full-screen takeover; lifecycle events →
   `ActiveTripController.reconcile` (REST is the truth).
2. **Offer** ([screens/incoming_offer_screen.dart](presentation/screens/incoming_offer_screen.dart))
   — countdown ring + sound + haptics; Accept creates the trip and opens the
   active-trip screen, Decline/expiry returns to searching.
3. **Active trip** ([screens/active_trip_screen.dart](presentation/screens/active_trip_screen.dart))
   — map + route + the single next action (Arrived → Start(OTP) → End). The
   driver's position streams to the rider as `trip.location` while active.
4. **Summary → rate rider → history/detail** round out the lifecycle.

## Layers

- `data/` — [trips_api.dart](data/trips_api.dart) (REST), models, providers, and
  the realtime coordinator.
- `presentation/controllers/` — `ActiveTripController` (source of truth for the
  live trip), `TripOfferController` (pending offer), `TripHistoryController`
  (paginated).
- `presentation/screens` + `presentation/widgets`.

## Endpoints / WS

`POST /drivers/me/trip-offers/:id/accept|decline` ·
`GET /drivers/me/trips[/current]` · `GET /trips/:id` ·
`POST /trips/:id/arrived|start|end|cancel|rate-rider|report`.
WS in: `trip.offered`, `trip.status.changed`, `trip.driver.arrived`,
`trip.completed`, `trip.cancelled`. WS out: `trip.location`.

> Note: the driver-facing `TripDto` does not expose rider name/phone, so the
> in-app "call rider" deep-link is deferred until the backend surfaces it.

See `docs/DRIVER_APP_SPRINT_PLAN.md` (D4).
