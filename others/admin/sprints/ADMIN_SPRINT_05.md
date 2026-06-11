# Admin Sprint A05 — Trips, Ratings, SOS Feed

> **Duration:** 2 weeks (parallel with Backend Sprint 7 + items from Sprint 6)
> **Goal:** Founder watches a simulated trip play out on `/trips/[id]/live` map in real time. When SOS triggers, the admin's safety feed lights up.

## Scope

### Pages

- `/trips` — list + filter (status, vehicle, date, driver, rider)
- `/trips/[id]` — detail page:
  - Map replay using `trip_location_pings`
  - State timeline (ACCEPTED → ARRIVED → STARTED → ENDED with timestamps)
  - Fare breakdown card
  - Both ratings + comments
  - Cancel button (admin override)
- `/trips/[id]/live` — for in-progress trips, real-time map + status
- `/safety/sos` — live SOS feed (real-time)
- `/safety/sos/[id]` — SOS detail with location, driver/rider, contacts notified

### Components

- `<TripReplayMap>` — animates the path with a moving marker, scrubber bar
- `<TripStateTimeline>` — vertical state ladder
- `<FareBreakdown>` — typography table
- `<SosCard>` — alert-styled row in feed
- `<RatingDisplay>` — star + count

### Tasks

- Trip list with smart filters
- Map replay component (animate marker through polyline)
- Real-time live page using `useTripWS` hook
- SOS feed page with WS subscription + sound alert
- Force-cancel modal w/ reason

## Endpoints consumed

- `GET /api/v1/admin/trips?status=&...`
- `GET /api/v1/admin/trips/:id`
- `POST /api/v1/admin/trips/:id/cancel`
- `GET /api/v1/admin/safety/sos?status=OPEN`
- `GET /api/v1/admin/safety/sos/:id`
- `POST /api/v1/admin/safety/sos/:id/resolve`
- WS events: `trip.status.changed`, `driver.location.updated`, `safety.sos.triggered`

## Acceptance

- [ ] Trip list paginated, sortable
- [ ] Detail page replays trip path correctly
- [ ] Live view updates in real time without refresh
- [ ] SOS feed shows new SOS within 5s of trigger, plays alert sound
- [ ] Admin can mark SOS resolved with notes

## Git plan

- `feature/admin-a05-trips-list`
- `feature/admin-a05-trip-detail`
- `feature/admin-a05-trip-replay-map`
- `feature/admin-a05-trip-live`
- `feature/admin-a05-sos-feed`
- `feature/admin-a05-sos-detail`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
