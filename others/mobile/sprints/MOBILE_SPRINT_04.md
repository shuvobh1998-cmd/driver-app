# Mobile Sprint M04 — On-Demand Booking Flow (Rider + Driver)

> **Duration:** 2 weeks
> **Goal:** Rider taps "Book Auto", waits ~15s, sees "Driver matched: Rahul, AS01 AB 1234". Driver simultaneously sees the offer card, slides to accept, sees pickup pin on their map.

## Scope

### Rider screens

- Vehicle type picker (from fare quote in M02)
- Payment method selector (CASH / UPI placeholder for M06)
- Notes for driver field
- "Confirm" → loading screen "Finding driver near you..."
- "Matched" screen: driver photo, name, rating, vehicle, plate, ETA, call button (phone deep-link), cancel button
- Cancel request flow with reason

### Driver screens

- Trip offer card overlay (full-screen if app is in foreground, system push if background)
- 15s countdown bar
- "Slide to accept" / "Decline" buttons
- After accept: navigate-to-pickup screen with rider info + tap-to-call

### Real-time

- WebSocket connect on app foreground (rider + driver)
- Subscribe to driver namespace for trip offers (driver)
- Subscribe to rider namespace for match (rider)

## Endpoints integrated

### Rider

- `POST /api/v1/rides/request`
- `GET /api/v1/rides/requests/:id`
- `POST /api/v1/rides/requests/:id/cancel`
- WS event `trip.matched`

### Driver

- WS event `trip.offered`
- `POST /api/v1/drivers/me/trip-offers/:id/accept`
- `POST /api/v1/drivers/me/trip-offers/:id/decline`

## Acceptance

- [ ] Rider request → driver receives offer within 5s
- [ ] Driver accepts → rider sees matched screen within 2s
- [ ] Decline → offer goes to next driver (verified in admin)
- [ ] Timeout (15s) → next driver auto-offered
- [ ] Race: 2 drivers tap accept simultaneously → only first wins, second sees "TRIP_ALREADY_ACCEPTED" toast
- [ ] Cancel request before match works
- [ ] Notes field appears on driver screen

## Status

- [x] Backend API delivered + verified end-to-end (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable = the backend endpoints + WS events + Swagger the Flutter team consumes.
> The matching/offer/accept machinery shipped in Sprint 4; this sprint fixed a
> matching-blocking bug and filled the rider/driver payload gaps M04 needs.

**Fixed this sprint**

- **Matching never ran** — `MatchingProducer` enqueued the BullMQ job with a
  colon in the job id (`match:<id>`), which BullMQ rejects, so every ride request
  sat PENDING and no driver was ever offered. Job id is now `match-<id>`. (Unit
  tests mock the queue, so this only showed up in live testing.)
- **`matchedTripId` leaked the numeric DB id** — replaced by a `matchedTrip`
  object keyed on the trip **public id**.

**Added this sprint**

- **Notes for driver** — `POST /rides/request` accepts `notes`; echoed on the
  request, carried in the `trip.offered` payload (with pickup/drop address), and
  copied onto the trip. Migration `0016_ride_notes`.
- **Matched-screen data** — `GET /rides/requests/:id` and the `trip.matched` WS
  event now include the matched **driver** (name, rating, avatar) + **vehicle**
  (type, plate, make/model/colour) + a rough `etaToPickupSec`. This gives the
  rider's matched screen a source before `GET /trips/:id` lands (Sprint 7).

**Already live (verified this sprint)**

- `POST /rides/request` · `GET /rides/requests/:id` · `POST /rides/requests/:id/cancel`
- `POST /drivers/me/trip-offers/:offerId/accept` · `.../decline`
- WS `trip.offered` (driver) · `trip.matched` (rider)

**End-to-end verification** (real Supabase + Redis + BullMQ, driver "Arjun",
rider "Priya"): driver online + ping near pickup → rider requests AUTO with
notes → **offer created** → driver accepts → rider `GET` shows **status MATCHED**
with `matchedTrip` = { tripId `trp_*`, driver Arjun Roy, vehicle AUTO/WB12XY4321/
Bajaj RE Yellow, etaToPickupSec } and `notes: "Bring helmet"`. Cancel-before-match
→ CANCELLED, re-cancel → REQUEST_NOT_CANCELLABLE. 253 unit tests green. Race /
decline / timeout are covered by unit tests.

## Notes

- **ETA-to-pickup** is a rough straight-line estimate (driver last-known location
  → pickup at ~25 km/h); null if the driver has no live location. Precise ETA can
  use routing later if needed.
- **`trip.matched` is rider-only** and carries the 4-digit `startOtp` (the rider
  shows it to the driver to start the trip in Sprint 7).
- The `trip.offered` driver offer card now has pickup/drop address + notes; the
  full trip detail (drop precise, fare breakdown) for the driver lands with the
  trip lifecycle (Sprint 7).
