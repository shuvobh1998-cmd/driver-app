# Sprint 4 — On-demand Matching

> **Duration:** 2 weeks
> **Theme:** Ride request flow, driver online/offline, Redis geo live driver pool, nearest-driver matching

## Goal

Founder opens admin map, sees live driver pins moving (test drivers via Postman pinging their location). A test rider requests a ride and the match appears in admin within 5 seconds.

## Why this sprint

This is the core Uber-style loop. After this sprint, an actual ride can be requested and matched — even if it can't be tracked or paid for yet (those come in Sprint 7 + 8).

## Features

### 1. Driver state management

- `POST /api/v1/drivers/me/online` — body: `{ vehicleId }`. Sets `status=ONLINE`, registers in Redis geo
- `POST /api/v1/drivers/me/offline` — removes from Redis, sets OFFLINE
- `POST /api/v1/drivers/me/location` — body: `{ lat, lng, speed?, bearing? }`. Updates `driver_states.current_location` (debounced 5s) + Redis GEO key
- `GET /api/v1/drivers/me/state`

### 2. Redis geo layer

- Key per vehicle type: `drivers:live:BIKE`, `drivers:live:AUTO`, etc.
- `GEOADD` on online, `GEORADIUS` for matching, `ZREM` on offline
- TTL: driver entry expires 90s if no location ping (auto-offline)

### 3. Ride request flow

- `POST /api/v1/rides/request` — body: `{ pickupLocation, dropLocation, vehicleType, paymentMethod }`
  - Computes fare estimate (Sprint 3)
  - Creates `ride_requests` row (status=PENDING)
  - Triggers async matching job (BullMQ)
- `GET /api/v1/rides/requests/:id` — current status
- `POST /api/v1/rides/requests/:id/cancel` — only if PENDING or MATCHED

### 4. Matching algorithm (BullMQ job)

- Find nearest N drivers (default 5) within radius (start 2km, expand to 5km after 10s no acceptance)
- Notify each driver in sequence with 15s acceptance window each (push + WebSocket)
- First to accept wins → create `trips` row (status=ACCEPTED), update `ride_requests.matched_trip_id`
- If all decline / timeout → expand radius or mark `NO_DRIVER`

### 5. Driver-side endpoints

- `POST /api/v1/drivers/me/trip-offers/:offerId/accept` — atomic claim (DB row lock to prevent double-accept)
- `POST /api/v1/drivers/me/trip-offers/:offerId/decline`

### 6. WebSocket events (skeleton — full in Sprint 7)

- Driver namespace: receives `trip.offered`, must accept/decline
- Rider namespace: receives `trip.matched`

### 7. Admin live map

- `/live-map` page
- Real-time: subscribes to `driver.location.updated` over WebSocket
- Filter by vehicle type
- Shows online/on-trip count, ride request markers

### 8. Admin ride requests

- `/rides/requests` — list with filters (status, time range)
- `/rides/requests/:id` — detail with map showing pickup/drop

## API endpoints delivered

| Method | Path                                         | Auth   | Purpose                |
| ------ | -------------------------------------------- | ------ | ---------------------- |
| POST   | `/api/v1/drivers/me/online`                  | driver | Go online              |
| POST   | `/api/v1/drivers/me/offline`                 | driver | Go offline             |
| POST   | `/api/v1/drivers/me/location`                | driver | Location ping          |
| GET    | `/api/v1/drivers/me/state`                   | driver | Current state          |
| POST   | `/api/v1/rides/request`                      | rider  | Request a ride         |
| GET    | `/api/v1/rides/requests/:id`                 | rider  | Request status         |
| POST   | `/api/v1/rides/requests/:id/cancel`          | rider  | Cancel request         |
| POST   | `/api/v1/drivers/me/trip-offers/:id/accept`  | driver | Accept offer           |
| POST   | `/api/v1/drivers/me/trip-offers/:id/decline` | driver | Decline offer          |
| GET    | `/api/v1/admin/live-map/drivers`             | admin  | Current online drivers |
| GET    | `/api/v1/admin/ride-requests`                | admin  | List requests          |

## DB migrations this sprint

1. `0007_driver_states` — `driver_states` table
2. `0008_ride_requests` — `ride_requests` table
3. `0009_trips_base` — `trips` table (state machine, partial — extended in Sprint 7/8)

## Admin panel pages this sprint

| Page                   | Purpose                       |
| ---------------------- | ----------------------------- |
| `/live-map`            | Real-time driver positions    |
| `/rides/requests`      | All ride requests, filterable |
| `/rides/requests/[id]` | Detail with map               |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + WS events + Swagger + Postman. No Flutter code from us.

**Rider endpoints shipped:**

- `POST /api/v1/rides/request` — body `{ pickupLocation, dropLocation, vehicleType, paymentMethod }` → returns `{ requestId, fare, estimates }`
- `GET /api/v1/rides/requests/:id` — poll status (PENDING / MATCHED / NO_DRIVER / CANCELLED)
- `POST /api/v1/rides/requests/:id/cancel`

**Driver endpoints shipped:**

- `POST /api/v1/drivers/me/online` — body `{ vehicleId }`
- `POST /api/v1/drivers/me/offline`
- `POST /api/v1/drivers/me/location` — body `{ lat, lng, speed?, bearing? }`, send every 5s while ONLINE/ON_TRIP
- `GET /api/v1/drivers/me/state`
- `POST /api/v1/drivers/me/trip-offers/:offerId/accept` — race-safe; returns 409 `TRIP_ALREADY_ACCEPTED` if lost
- `POST /api/v1/drivers/me/trip-offers/:offerId/decline`

**WebSocket events shipped (Socket.IO):**

- `trip.offered` → **driver** — payload: `{ offerId, requestId, rider, pickup, drop, fare, expiresAt }` (15s window)
- `trip.matched` → **rider** — payload: `{ tripId, driver, vehicle, eta }`
- `driver.location.updated` → **admin only** — for live map

**Auth on socket:** JWT in `auth.token`, `token` query param, OR `Authorization: Bearer` header.

**Conventions Flutter must match:**

- Location ping cadence: every 5s (server debounces DB writes; pings can be more frequent for smoother map but rate-limited to 1/2s)
- Auto-offline after 90s without a ping
- Race condition: 2 drivers tap accept → only first wins. Loser shows toast from `TRIP_ALREADY_ACCEPTED` error.

**Artifacts:**

- Postman collection: `docs/postman/sprint-04.json`
- Socket.IO test client snippet in `docs/REALTIME_EVENTS.md`

**Unblocks mobile sprint M04** — driver go-online toggle, rider book flow, trip offer screen, match screen. See [`docs/mobile/sprints/MOBILE_SPRINT_04.md`](../mobile/sprints/MOBILE_SPRINT_04.md).

## Demo checklist

- [ ] Run 3 Postman-scripted drivers going online + pinging location every 5s in Kolkata
- [ ] Founder opens `/live-map`, sees 3 pins moving
- [ ] Post a ride request from a 4th Postman "rider"
- [ ] Watch one of the 3 drivers receive offer, accept
- [ ] Admin `/rides/requests/[id]` shows MATCHED status with assigned driver

## Definition of Done

- [ ] Matching algorithm tested with concurrent drivers (no double-accept)
- [ ] Redis GEO entries cleaned on offline + on disconnect + on stale (90s TTL)
- [ ] WebSocket auth works (JWT in query)
- [ ] Admin live map updates without page refresh
- [ ] e2e: rider request → driver accept → trip created
- [ ] Race condition test: 2 drivers accept same offer → only first wins, second gets `TRIP_ALREADY_ACCEPTED`
- [ ] Git tag `v0.4.0-sprint-4`

## Git plan

- `feature/sprint-4-driver-state` — online/offline/location endpoints
- `feature/sprint-4-redis-geo` — Redis geo wrapper service
- `feature/sprint-4-ride-request` — request creation + cancel
- `feature/sprint-4-matching-job` — BullMQ matching worker
- `feature/sprint-4-trip-offer-accept` — atomic accept logic
- `feature/sprint-4-ws-skeleton` — Socket.IO gateway baseline
- `feature/sprint-4-admin-live-map` — Leaflet realtime map page

## Status

- [x] All 8 features complete
- [x] Feature 1 — Driver state management
- [x] Feature 2 — Redis geo layer
- [x] Feature 3 — Ride request flow
- [x] Feature 4 — Matching algorithm (BullMQ worker)
- [x] Feature 5 — Driver-side endpoints
- [x] Feature 6 — WebSocket events
- [x] Feature 7 — Admin live map
- [x] Feature 8 — Admin ride requests

## Delivered

### Feature 1 — Driver state management (`feature/sprint-4-driver-state`)

- Migration `0008_driver_states` — `driver_states` table (geography `current_location`
  - GIST index, `DriverStatus` enum, FKs to `users`/`vehicles`). `current_trip_id`
    is a plain column for now; its FK lands with the `trips` table.
- `POST /api/v1/drivers/me/online` — `{ vehicleId }` (vehicle public id, must be
  owned + ACTIVE). Sets status ONLINE, stamps `went_online_at`, and registers the
  driver into the Redis GEO pool if a last-known location exists.
- `POST /api/v1/drivers/me/offline` — `ZREM` from the live pool + status OFFLINE.
- `POST /api/v1/drivers/me/location` — `{ lat, lng, speed?, bearing? }`. Refreshes
  the Redis GEO entry on every ping; the Postgres `current_location` write is
  debounced to once / 5s via a Redis NX key. Requires ONLINE or ON_TRIP.
- `GET /api/v1/drivers/me/state` — current status, vehicle, last position.
- New: `DriverStateService`, `DriverGeoService` (Redis geo write wrapper),
  `DriverStateController`; `RedisService.setIfAbsent` debounce helper. Unit tests
  in `driver-state.service.spec.ts` (10 cases).

### Feature 2 — Redis geo layer (`feature/sprint-4-redis-geo`)

- `DriverGeoService.search()` — `GEOSEARCH BYRADIUS … ASC COUNT n WITHCOORD WITHDIST`
  over `drivers:live:<type>`, returns nearest-first `NearbyDriver[]` (user id,
  distance m, lng/lat). This is the read side the matching job (Feature 4) consumes.
- 90s auto-offline TTL: GEO members can't carry a per-member TTL, so each
  `upsert` also stamps a parallel `drivers:seen:<type>` sorted set (epoch-ms).
  `reapStale(90)` evicts members older than the cutoff from both keys and returns
  their user ids.
- `DriverGeoSweepService` — a dependency-free `setInterval` sweeper (30s, timer
  `unref`'d, non-overlapping) that reaps stale entries and flips those drivers
  OFFLINE in Postgres (ONLINE → OFFLINE only; ON_TRIP is left alone).
- No DB migration (pure Redis). Unit tests in `driver-geo.service.spec.ts` (6) and
  `driver-geo-sweep.service.spec.ts` (4).

### Feature 3 — Ride request flow

- Migration `0009_ride_requests` — `ride_requests` table (geography
  `pickup_location`/`drop_location` + GIST indexes, `RideRequestStatus` +
  `PaymentMethod` enums, fare snapshot, FK to `users`). `matched_trip_id` is a
  plain column until the `trips` table lands (Sprint 7); `payment_method` is
  carried here so trip creation can reuse the rider's choice.
- `POST /api/v1/rides/request` — `{ pickupLocation, dropLocation, vehicleType,
paymentMethod, pickupAddress?, dropAddress? }`. Computes a fare snapshot via the
  Sprint 3 `FaresService` (404 on no route / no pricing), inserts a PENDING row,
  and enqueues the async match job. Returns `req_*` with the fare + estimates.
- `GET /api/v1/rides/requests/:id` — owner-scoped lookup by public id.
- `POST /api/v1/rides/requests/:id/cancel` — allowed only while PENDING or
  MATCHED; a guarded conditional UPDATE prevents a cancel/​match race. (Trip-side
  cancellation cascade is Sprint 7.)
- BullMQ wiring: new `MatchingModule` + `MatchingProducer` own the `matching`
  queue (dedicated ioredis connection, `maxRetriesPerRequest: null`, idempotent
  `jobId = match:<id>`, 3 attempts/exp backoff). The **worker that consumes these
  jobs is Feature 4** — until then jobs queue up. Added a root pnpm `ioredis`
  override to dedupe bullmq's bundled copy.
- Unit tests in `rides.service.spec.ts` (7 cases).

### Feature 4 — Matching algorithm (BullMQ worker)

- Migration `0010_trips_base` — `trips` (partial base: geography pickup/drop +
  GIST indexes, `TripStatus`/`PaymentStatus`/`TripParty` enums, fare snapshot,
  FKs to ride_requests/users/vehicles) and `trip_offers` (`TripOfferStatus`,
  `expires_at`, unique `(ride_request_id, driver_user_id)`). Added the `off`
  public-id prefix. `matched_trip_id`/`current_trip_id` stay plain columns (no FK).
- `MatchingWorker` — BullMQ consumer (own ioredis conn, concurrency 5) that runs
  `MatchingService.runMatch` per job.
- `MatchingService.runMatch` — loads the request, sweeps nearest drivers via
  `DriverGeoService.search` (2km → widen to 5km after 10s), creates a `trip_offers`
  row per driver and pushes `trip.offered` (FCM; WebSocket is F6), waits the 15s
  window, finalizes MATCHED / NO_DRIVER / CANCELLED. Candidates are re-validated
  against `driver_states` (still ONLINE + has a vehicle).
- `MatchingService.acceptOffer` — **atomic claim** in one transaction via guarded
  conditional updates: claim the offer (OFFERED+unexpired) → claim the request
  (PENDING→MATCHED) → INSERT the trip (copying geography/fare off the request) →
  link `matched_trip_id` → expire sibling offers → driver ON_TRIP + remove from
  the live pool. Concurrent accepts leave one winner; the loser rolls back with
  `TRIP_ALREADY_ACCEPTED`. `declineOffer` flips OFFERED→DECLINED so the worker
  advances immediately. **The driver HTTP endpoints that call these are Feature 5.**
- Set `enableReadyCheck: false` on the BullMQ connections (Upstash blocks `INFO`).
- Unit tests in `matching.service.spec.ts` (9 cases).

### Feature 5 — Driver-side endpoints

- `POST /api/v1/drivers/me/trip-offers/:offerId/accept` — thin controller over
  `MatchingService.acceptOffer`; returns the created trip (`trp_*` + status).
  Losing a race / stale offer → 409 (`TRIP_ALREADY_ACCEPTED` / `OFFER_EXPIRED` /
  `OFFER_NOT_ACCEPTABLE`).
- `POST /api/v1/drivers/me/trip-offers/:offerId/decline` — over
  `MatchingService.declineOffer`; 204 on success, 409 if no longer pending.
- `TripOffersController` in the matching module (no new service logic — the
  atomic claim landed in F4). Routes verified live in the OpenAPI spec.
- This closes the on-demand loop: request → match → offer → **accept → trip**.

### Feature 6 — WebSocket events (Socket.IO baseline)

- `RealtimeGateway` (Socket.IO, attached under Fastify via `IoAdapter` in
  `main.ts`). Sockets authenticate on connect with a JWT (DoD: `auth.token`, the
  `token` query param, or a Bearer header) through `WsAuthService` — same checks
  as `JwtAuthGuard`. Authenticated sockets join `user:<id>` and, for admins,
  `role:ADMIN`. Bad/absent token → `error` event + disconnect.
- Events emitted (receive-only for clients; drivers still act via the F5 HTTP
  endpoints): `trip.offered` → driver (`MatchingService` on each offer, alongside
  the FCM push), `trip.matched` → rider (`MatchingService` on accept),
  `driver.location.updated` → admins (`DriverStateService` on every location ping).
- `RealtimeModule` is `@Global` so `MatchingService`/`DriverStateService` inject
  the gateway without an import dance.
- Single namespace + rooms for the skeleton (Sprint 7 can split namespaces if
  needed); no inbound `@SubscribeMessage` handlers yet. Verified live: Socket.IO
  handshake serves under Fastify on boot. Unit tests in `realtime.gateway.spec.ts`
  (6: emit routing + connect/auth/disconnect).

### Feature 7 — Admin live map

- Backend `GET /api/v1/admin/live-map/drivers` (admin-only) — snapshot of drivers
  currently ONLINE/ON_TRIP with a known position (driver, status, vehicle, lat/lng,
  last-update). `AdminLiveMapController`/`Service` in the admin module; 1 unit test.
  Verified live in the OpenAPI spec.
- Admin `/live-map` page (Next.js + the reusable Leaflet `Map`): seeds from the
  snapshot, opens an authenticated Socket.IO connection (`socket.io-client`, JWT
  in the handshake) and patches pins live off `driver.location.updated`. Vehicle-type
  filter (All/BIKE/AUTO/CNG/CAR), online/on-trip counts, a connection indicator,
  and a 20s snapshot re-poll to catch status changes + drivers going offline (the
  socket only streams positions). Added a `Live Map` sidebar item.
- Ride-request markers on the map are deferred to Feature 8 (which builds the
  ride-requests data layer).

### Feature 8 — Admin ride requests

- Backend (admin-only): `GET /api/v1/admin/ride-requests` (paginated; filter by
  `status` + `from`/`to` time range) and `GET /api/v1/admin/ride-requests/:id`
  (detail: pickup/drop lat-lng + addresses, rider, and the matched trip + driver
  - vehicle once accepted). `AdminRideRequestsController`/`Service` in the admin
    module; 3 unit tests. Both paths verified live in the OpenAPI spec.
- Admin `/rides/requests` — filterable table (status select + date range),
  paginated, status badges, fare, rider, route. `/rides/requests/[id]` — detail
  with a Leaflet map showing pickup + drop pins and the matched-driver panel
  (covers the demo "shows MATCHED status with assigned driver"). New
  `RideRequestStatusBadge` + `Ride Requests` sidebar item.
- Note: the live-map ride-request overlay (mentioned in F7) was left out — the
  `Map` component uses one default pin icon, so mixing driver and request pins
  would be ambiguous; deferred until the component supports per-marker icons.

## Carryover

None — all 8 features delivered.

## Notes / Blockers

- BullMQ runs on Upstash with `enableReadyCheck: false` (Upstash blocks `INFO`).
- The matching worker (`MatchingWorker`) and geo sweeper (`DriverGeoSweepService`)
  run in-process; when the backend scales beyond one instance they should move to
  a dedicated worker process (post-MVP).

## Notes / Blockers
