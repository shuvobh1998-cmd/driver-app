# Mobile Sprint M05 — Trip Lifecycle, Live Tracking, Ratings, History

> **Duration:** 2 weeks
> **Goal:** End-to-end trip happens: driver picks up → starts (with OTP) → drives → ends. Rider sees live driver pin moving on map. Both rate each other. Trip appears in history.

## Scope

### Rider screens

- En route screen: live driver pin moving toward pickup, ETA countdown, rider's 4-digit start-OTP shown prominently
- "Driver arrived" notification + sound
- Trip in progress: full-screen map with driver+self pins + drop pin + ETA to drop
- Trip ended: fare card, rate-driver screen (1-5 stars + optional comment)
- Trip history: list with date, route summary, fare, status
- Trip detail (past trip): map of taken route, fare breakdown, both ratings, "Report problem" link

### Driver screens

- Going to pickup: navigation hint, tap-to-call rider
- At pickup: OTP entry pad ("Ask rider for OTP")
- Trip in progress: navigation hint, end-trip button
- Trip ended: confirm fare + cash collected toggle (M06 finishes this)
- Rate rider screen
- Trip history + earnings chip

### Real-time

- Join WS room `trip:{id}` after accept/match
- Driver: broadcast location ping every 5s during ACCEPTED + STARTED states
- Rider: listen for `driver.location.updated`, `trip.status.changed`, `trip.driver.arrived`, `trip.completed`

## Endpoints integrated

### Driver

- `POST /api/v1/trips/:id/arrived`
- `POST /api/v1/trips/:id/start` (with OTP)
- `POST /api/v1/trips/:id/end`
- `POST /api/v1/trips/:id/rate-rider`
- `GET /api/v1/drivers/me/trips` (history)
- `GET /api/v1/drivers/me/trips/current`

### Rider

- `GET /api/v1/trips/:id`
- `POST /api/v1/trips/:id/cancel`
- `POST /api/v1/trips/:id/rate-driver`
- `POST /api/v1/trips/:id/report`
- `GET /api/v1/trips/me`

### WS

- `trip.status.changed`, `trip.driver.arrived`, `driver.location.updated`, `trip.completed`, `trip.cancelled`

## Acceptance

- [ ] Trip plays through all states without manual refresh
- [ ] Rider sees driver pin move smoothly (no jitter — throttle to 1 update/s)
- [ ] OTP must be entered to start trip
- [ ] Mid-trip cancellation (rider after start) → cancellation fee preview shown
- [ ] Ratings persist + visible in admin
- [ ] History list paginates correctly

## Status

- [x] Backend API delivered + verified end-to-end (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable = the backend endpoints + WS events + Swagger the Flutter team consumes.
> Most of the trip lifecycle already shipped in the trips module; this sprint added
> the two missing endpoints and verified the whole lifecycle live.

**Added this sprint**

- `GET /drivers/me/trips/current` + `GET /trips/me/current` — the user's single
  active trip (ACCEPTED/ARRIVED/STARTED), `404 NO_ACTIVE_TRIP` otherwise, so the
  app resumes the trip screen on relaunch.
- `POST /trips/:id/report` — either party files a problem report (category +
  description). Migration `0017_trip_reports`; admin triage lands in Sprint 10.

**Already live (verified this sprint)**

- Driver: `POST /trips/:id/arrived` · `/start` (OTP-gated) · `/end` · `/rate-rider` ·
  `GET /drivers/me/trips`
- Rider: `GET /trips/:id` · `POST /trips/:id/cancel` · `/rate-driver` · `GET /trips/me`
- WS: `trip.status.changed`, `trip.driver.arrived`, `trip.completed`,
  `trip.cancelled` (emitted across the lifecycle); in-trip driver location is
  streamed to the trip room.

**End-to-end verification** (real Supabase + Redis): accept → **arrived** → start
**without OTP → `OTP_REQUIRED` (400)**, **wrong OTP → `OTP_INVALID` (409)**,
**correct OTP → STARTED** (rider saw the OTP; the driver's view shows `null`) →
**end** (totalFare 10919 from measured pings, actualDuration 264s) → rate-driver 5

- rate-rider 4 → re-rate → `ALREADY_RATED` → **report** (rpt\_\*) → `current` now
  `404 NO_ACTIVE_TRIP` for both → history paginates. 257 unit tests green.

## Notes

- **Start OTP is enforced** — the 4-digit OTP is shown only to the rider (the
  `trips/:id` and `current` responses hide it from the driver and admins) and the
  driver must enter it to start. `OTP_REQUIRED` (400) / `OTP_INVALID` (409).
- **Cancellation-fee preview after a trip starts is NOT built.** `POST /trips/:id/
cancel` is allowed only before STARTED (ACCEPTED/ARRIVED). A mid-trip cancel-fee
  needs a founder-set policy (open question #1 in the API plan) — deferred, not
  invented. `/fares/cancellation-preview` stays unbuilt.
- **In-trip rider tracking event name:** the gateway streams in-trip driver
  positions to the `trip:{id}` room as `trip.location.updated`. The §21 catalog
  calls it `driver.location.updated` (which is currently the admin-map event).
  Flutter should subscribe to `trip.location.updated` for the rider tracking map;
  worth reconciling the catalog later.
