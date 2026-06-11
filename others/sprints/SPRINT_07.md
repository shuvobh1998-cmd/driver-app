# Sprint 7 — Trip Lifecycle & Realtime

> **Duration:** 2 weeks
> **Theme:** Full trip state machine, WebSocket location streaming, ratings

## Goal

Founder watches a complete simulated trip on the admin map: a driver pin moves from accept → pickup → drop, status changes update live, rating is captured at the end.

## Why this sprint

After matching (Sprint 4), the trip must actually happen end-to-end. This sprint connects the dots — driver arrives, starts trip, ends trip, both rate. Closes the on-demand loop except for payments (Sprint 8).

## Features

### 1. Trip state transitions (driver actions)

- `POST /api/v1/trips/:id/arrived` — driver reached pickup
- `POST /api/v1/trips/:id/start` — driver started (OTP verification optional: rider gives 4-digit code shown in their app)
- `POST /api/v1/trips/:id/end` — driver ended → computes actual distance/duration/fare
- `POST /api/v1/trips/:id/cancel` — body `{ reason }` — driver or rider, before STARTED

### 2. Trip queries

- `GET /api/v1/trips/:id` — full trip detail (rider/driver/admin)
- `GET /api/v1/trips/me` — user's trip history (paginated)
- `GET /api/v1/drivers/me/trips` — driver's trip history

### 3. Live location streaming

- WebSocket: driver streams location during trip → server fans out to rider + admin subscribers of that trip
- Server persists every Nth ping (e.g., 1 in 5, or 1 every 15s) to `trip_location_pings`
- Disconnect handling: trip stays active, last location persists

### 4. Trip OTP (start verification)

- On `accept`, generate 4-digit code, return to rider only
- Driver enters code via app → `POST /trips/:id/start` with `{ otp }`
- Prevents fraud (driver starting trip without rider present)

### 5. Distance / duration accuracy

- On `end`, compute actual distance from `trip_location_pings` polyline length
- Recompute fare with actual values
- Store final breakdown in `fare_breakdown` JSONB

### 6. Ratings

- `POST /api/v1/trips/:id/rate-driver` — body `{ rating, comment? }` (rider)
- `POST /api/v1/trips/:id/rate-rider` — body `{ rating, comment? }` (driver)
- Updates `driver_profiles.rating_avg` + `rating_count` denormalized

### 7. Admin

- `/trips` — list with status filter
- `/trips/[id]` — detail page with:
  - Map showing actual route from `trip_location_pings`
  - Timeline of state transitions
  - Fare breakdown
  - Both ratings + comments
- `/trips/[id]/live` — for in-progress trips, real-time map

### 8. WebSocket event vocabulary (locked)

- `trip.status.changed` — payload: `{ tripId, status, at }`
- `trip.location.updated` — payload: `{ tripId, location, recordedAt, speed?, bearing? }`
- `trip.driver.arrived` — payload: `{ tripId, at }`
- `trip.completed` — payload: `{ tripId, summary }`
- `trip.cancelled` — payload: `{ tripId, by, reason, at }`

## API endpoints delivered

| Method | Path                            | Auth           | Purpose               |
| ------ | ------------------------------- | -------------- | --------------------- |
| POST   | `/api/v1/trips/:id/arrived`     | driver         | Mark arrived          |
| POST   | `/api/v1/trips/:id/start`       | driver         | Start trip (with OTP) |
| POST   | `/api/v1/trips/:id/end`         | driver         | End trip              |
| POST   | `/api/v1/trips/:id/cancel`      | rider/driver   | Cancel                |
| GET    | `/api/v1/trips/:id`             | involved party | Detail                |
| GET    | `/api/v1/trips/me`              | rider          | History               |
| GET    | `/api/v1/drivers/me/trips`      | driver         | Earnings history      |
| POST   | `/api/v1/trips/:id/rate-driver` | rider          | Rate driver           |
| POST   | `/api/v1/trips/:id/rate-rider`  | driver         | Rate rider            |
| GET    | `/api/v1/admin/trips`           | admin          | All trips             |
| GET    | `/api/v1/admin/trips/:id`       | admin          | Detail incl. path     |

## DB migrations this sprint

1. `0018_trips_extended` — additional columns (`arrived_at`, `started_at`, ratings, etc.)
2. `0019_trip_location_pings` — append-only pings table

## Admin panel pages this sprint

| Page               | Purpose                            |
| ------------------ | ---------------------------------- |
| `/trips`           | List + filter                      |
| `/trips/[id]`      | Full detail with replay            |
| `/trips/[id]/live` | Real-time view of in-progress trip |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + WS events + Swagger + Postman. No Flutter code from us.

**Endpoints shipped:**

- Trip state (driver): `POST /api/v1/trips/:id/arrived`, `/start` (with `{ otp }`), `/end`, `/cancel`
- Trip queries: `GET /api/v1/trips/:id`, `/trips/me`, `/drivers/me/trips`
- Ratings: `POST /api/v1/trips/:id/rate-driver` (rider), `/rate-rider` (driver)

**WebSocket events shipped (locked vocabulary):**

- `trip.status.changed` — `{ tripId, status, at }` → both rider + driver
- `trip.location.updated` — `{ tripId, location, recordedAt, speed?, bearing? }` → rider (per-trip room) + admin
- `trip.driver.arrived` — `{ tripId, at }` → rider
- `trip.completed` — `{ tripId, summary }` → both
- `trip.cancelled` — `{ tripId, by, reason, at }` → both

**Conventions Flutter must match:**

- Trip OTP UX: rider sees a 4-digit code in their app, says it aloud at pickup, driver types it into the start screen
- Location ping: driver app sends location every 5s while ON_TRIP (max 1/2s rate-limit server-side)
- Per-trip room: socket subscribes to `trip:<tripId>` on accept, unsubscribes on `trip.completed`/`trip.cancelled`
- Cancel windows: free cancel before STARTED; after that, cancellation fee per Sprint 8 policy

**Artifacts:**

- Postman collection: `docs/postman/sprint-07.json`
- WS payload schemas in [`docs/REALTIME_EVENTS.md`](../REALTIME_EVENTS.md)

**Unblocks mobile sprint M05** — live tracking screen, trip OTP entry, end-of-trip ratings, trip history. See [`docs/mobile/sprints/MOBILE_SPRINT_05.md`](../mobile/sprints/MOBILE_SPRINT_05.md).

## Demo checklist

- [ ] Run scripted rider + driver
- [ ] Driver accepts → moves toward pickup (location pings) → admin pin moves
- [ ] Driver hits `arrived` → status changes on admin
- [ ] Rider shows OTP, driver enters → trip starts → admin status updates
- [ ] Driver moves to drop → ends trip → admin sees actual distance + fare
- [ ] Both rate each other → admin sees ratings on trip detail

## Definition of Done

- [ ] State machine enforced (can't skip states, can't reverse)
- [ ] WebSocket auth works, room-based fanout (per trip)
- [ ] Location ping rate-limited (max 1/2s/driver)
- [ ] Trip location polyline visible on admin map
- [ ] Driver rating average updates correctly
- [ ] OTP-based start prevents fake starts
- [ ] e2e: full trip happy path test
- [ ] Edge cases: cancel after arrived, cancel after start (charge cancellation fee per policy)
- [ ] Git tag `v0.7.0-sprint-7`

## Git plan

- `feature/sprint-7-trip-states` — state machine + transition endpoints
- `feature/sprint-7-trip-otp` — OTP for start verification
- `feature/sprint-7-location-stream` — WS streaming + persistence
- `feature/sprint-7-trip-history` — history endpoints
- `feature/sprint-7-ratings` — rating endpoints + denorm
- `feature/sprint-7-admin-trip-views` — list, detail, live pages

## Status

- [ ] Not started

## Delivered

## Carryover

## Notes / Blockers
