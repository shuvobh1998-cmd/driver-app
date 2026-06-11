# Sprint 3 — Maps & Fare Engine

> **Duration:** 2 weeks
> **Theme:** Geocoding, address book, route distance, fare estimation per vehicle type, pricing config

## Goal

Founder changes per-km rate for autos in admin → opens Postman → estimates a fare → sees the new price reflected immediately.

## Why this sprint

No money moves without a fare. Riders need an upfront price before requesting. Drivers need clear pricing rules. Founder needs to tune pricing based on competition.

## Features

### 1. Address book

- `GET /api/v1/users/me/addresses`
- `POST /api/v1/users/me/addresses` — label, address_text, location
- `PATCH /api/v1/users/me/addresses/:id`
- `DELETE /api/v1/users/me/addresses/:id`

### 2. Geocoding wrapper

- `GET /api/v1/maps/geocode?q=<query>` — forward geocoding
- `GET /api/v1/maps/reverse-geocode?lat=&lng=` — reverse
- Internally: Nominatim in dev (with rate-limiter), abstracted so we swap to OLA/Google in prod
- Caching: Redis 24h cache per query string

### 3. Route + distance

- `POST /api/v1/maps/route` — body: `{ origin: {lat,lng}, destination: {lat,lng} }`
- Returns: `{ distance_m, duration_s, polyline, waypoints }`
- Provider: OSRM (public demo) in dev, OLA Maps Directions in prod
- Cached in Redis 1h by `{origin,dest}` hash

### 4. Fare estimation

- `POST /api/v1/fares/estimate` — body: `{ origin, destination, vehicleType }`
- Returns: `{ estimatedFare, breakdown: {baseFare, distanceFare, timeFare, platformFee, gst, total}, estimatedDistance, estimatedDuration }`
- Logic: looks up active `pricing_rules` row for `(vehicleType, city)` → applies `base + (distance_km × per_km) + (duration_min × per_minute) → max(value, minimum_fare) → add platform_fee% → add gst%`
- All math in integer paise; round at the very end

### 5. Pricing rules admin

- `GET /api/v1/admin/pricing-rules`
- `POST /api/v1/admin/pricing-rules` — creates new rule (closes previous one's `effective_to`)
- `GET /api/v1/admin/pricing-rules/history?vehicleType=AUTO`
- Audit: every change records `created_by_user_id`

### 6. Admin panel pages

- `/pricing` — current rules per vehicle type with edit modal
- `/pricing/history` — historical pricing audit
- `/users/[id]/addresses` — view user's saved addresses

### 7. Maps in admin

- Leaflet + OSM tiles
- Reusable `<Map>` component (will be used heavily in Sprint 4-5)

## API endpoints delivered

| Method | Path                                  | Auth   | Purpose              |
| ------ | ------------------------------------- | ------ | -------------------- |
| GET    | `/api/v1/users/me/addresses`          | rider  | List addresses       |
| POST   | `/api/v1/users/me/addresses`          | rider  | Save address         |
| PATCH  | `/api/v1/users/me/addresses/:id`      | rider  | Update               |
| DELETE | `/api/v1/users/me/addresses/:id`      | rider  | Remove               |
| GET    | `/api/v1/maps/geocode`                | bearer | Forward geocode      |
| GET    | `/api/v1/maps/reverse-geocode`        | bearer | Reverse geocode      |
| POST   | `/api/v1/maps/route`                  | bearer | Route between points |
| POST   | `/api/v1/fares/estimate`              | bearer | Fare quote           |
| GET    | `/api/v1/admin/pricing-rules`         | admin  | Active rules         |
| POST   | `/api/v1/admin/pricing-rules`         | admin  | Create rule          |
| GET    | `/api/v1/admin/pricing-rules/history` | admin  | Audit log            |

## DB migrations this sprint

1. `0006_saved_addresses` — `saved_addresses` table with GIST index on `location` ✅
2. `0007_pricing_rules` — `pricing_rules` table (includes `created_by_user_id` audit column for Feature 5) ✅
3. Seed: initial Kolkata pricing for BIKE, AUTO, CNG, CAR (research market rates) ✅

## Admin panel pages this sprint

| Page                    | Purpose                  |
| ----------------------- | ------------------------ |
| `/pricing`              | Edit per-vehicle pricing |
| `/pricing/history`      | Audit trail              |
| `/users/[id]/addresses` | User's saved places      |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + Swagger + Postman. No Flutter code from us.

**Endpoints shipped:**

- Saved addresses: `GET/POST /api/v1/users/me/addresses`, `PATCH/DELETE /api/v1/users/me/addresses/:id`
- Maps: `GET /api/v1/maps/geocode?q=`, `GET /api/v1/maps/reverse-geocode?lat=&lng=`, `POST /api/v1/maps/route`
- Fare: `POST /api/v1/fares/estimate` — returns `{ estimatedFare, breakdown, estimatedDistance, estimatedDuration }`

**WebSocket events:** none yet.

**Conventions Flutter must match:**

- All money in **integer paise** (e.g., `12500` = ₹125.00). Format on display only.
- Locations as `{ lat, lng }` (decimal degrees, WGS84).
- Polyline format: Google encoded polyline algorithm (rendered via `flutter_polyline_points`).

**Artifacts:**

- Postman collection: `docs/postman/sprint-03.json`

**Unblocks mobile sprint M03** — address book, address autocomplete, fare quote preview, route render on rider map. See [`docs/mobile/sprints/MOBILE_SPRINT_03.md`](../mobile/sprints/MOBILE_SPRINT_03.md).

## Demo checklist

- [ ] Founder opens `/pricing`, sees current AUTO rate
- [ ] Changes per-km from ₹12 to ₹14, saves
- [ ] In Postman, `POST /fares/estimate` returns new fare
- [ ] Show `/pricing/history` showing the audit entry
- [ ] Show geocode of "Park Street, Kolkata" returns lat/lng
- [ ] Show route between two points returns polyline

## Definition of Done

- [ ] All endpoints functional and Swagger-documented
- [ ] Pricing rule changes are atomic + audited
- [ ] Geocode/route caching cuts external calls (verify in Redis)
- [ ] Nominatim rate limiter prevents 429s
- [ ] Fare math unit tests (edge cases: min fare, zero distance, etc.)
- [ ] Git tag `v0.3.0-sprint-3` pushed

## Git plan

- `feature/sprint-3-addresses` — saved addresses CRUD
- `feature/sprint-3-geocoding` — geocode/reverse wrappers + cache
- `feature/sprint-3-routing` — route endpoint + cache
- `feature/sprint-3-fare-engine` — fare math + estimate endpoint
- `feature/sprint-3-pricing-admin` — admin CRUD + history
- `feature/sprint-3-admin-map` — Leaflet component

## Status

- [x] Feature 1 — Address book (CRUD)
- [x] Feature 2 — Geocoding wrapper
- [x] Feature 3 — Route + distance
- [x] Feature 4 — Fare estimation
- [x] Feature 5 — Pricing rules admin
- [x] Feature 6 — Admin panel pages
- [x] Feature 7 — Maps in admin

## Delivered

> Fill at end of sprint.

- **Address book** — `saved_addresses` table (migration `0006`) + CRUD under
  `/api/v1/users/me/addresses` (list, create, update, delete), scoped to the
  authenticated user. PostGIS `location` handled via raw SQL in `AddressesService`
  (`ST_MakePoint` / `ST_X` / `ST_Y`). Unit tests in `addresses.service.spec.ts`.
- **Geocoding wrapper** — `GET /api/v1/maps/geocode?q=…` and
  `GET /api/v1/maps/reverse-geocode?lat=&lng=`. Provider abstraction
  (`GEOCODING_PROVIDER` token) with a Nominatim implementation that throttles
  outbound calls (≥1.1s spacing) and 5s-timeouts via AbortController. Results
  cached in Redis for 24h (`geocode:fwd:<query>` / `geocode:rev:<lat,lng>`),
  with reverse coords rounded to 5 decimals to widen cache hits. Default
  `NOMINATIM_USER_AGENT` uses the `Mozilla/5.0 (compatible; …)` form Nominatim's
  abuse filter accepts; placeholder UAs get 403'd.
- **Route + distance** — `POST /api/v1/maps/route` with body
  `{ origin, destination }`. Returns `{ distanceMeters, durationSeconds, polyline,
waypoints }`. Provider abstraction (`ROUTING_PROVIDER` token) with an OSRM
  implementation hitting the public demo (`/route/v1/driving/...?overview=full&geometries=polyline`),
  10s `AbortController` timeout, distance/duration rounded to ints. `RoutingService`
  caches results in Redis for 1h keyed by 5-decimal-rounded origin/destination
  coords; negative results cached too. `code != 'Ok'` or empty routes → `404
NO_ROUTE`; HTTP/network failure → `503 SERVICE_UNAVAILABLE`. **Field naming
  note:** sprint spec wrote `distance_m / duration_s`; final API uses
  `distanceMeters / durationSeconds` to honour the camelCase convention.
- **Fare estimation** — `POST /api/v1/fares/estimate` with body `{ origin,
destination, vehicleType }`. Calls `RoutingService` (re-uses the 1h cache)
  for distance/duration, then `pricing_rules` (migration `0007`) for the active
  rate. Math in integer paise per spec: `round(distance_m × per_km / 1000)` +
  `round(duration_s × per_minute / 60)` + `base`, floored at `minimum_fare`,
  then `+ round(billable × platform_fee_pct / 100)` and
  `+ round((billable + platformFee) × gst_pct / 100)`. Returns
  `{ estimatedFare, breakdown, estimatedDistance, estimatedDuration }`. Routing
  failure → `404 NO_ROUTE`; no active rule → `404 PRICING_NOT_FOUND`. Seed
  ships default Kolkata rates for BIKE/AUTO/CNG/CAR so the endpoint works out
  of the box.
- **Pricing rules admin** — `GET /api/v1/admin/pricing-rules` (current active
  rules, one per vehicle type), `POST /api/v1/admin/pricing-rules` (create a
  new rule), `GET /api/v1/admin/pricing-rules/history?vehicleType=AUTO` (full
  audit trail per vehicle type, newest first). All gated by `@Roles(ADMIN)`.
  The create endpoint is wrapped in a Prisma interactive transaction: an
  `updateMany` closes any active row (`effective_to = now`) and a `create`
  inserts the new row with `effective_from = now` and the admin's id as
  `created_by_user_id` — both writes succeed or roll back together. Two
  simultaneous admin writes could briefly leave two active rows; acceptable
  for MVP, tighten with SERIALIZABLE isolation or a partial unique index if
  it ever matters.
- **Admin panel pages** — `/pricing` (one row per vehicle type with a `<PricingEditDialog>`
  modal that posts a new rule), `/pricing/history` (full audit table with a
  vehicle-type filter; the open-ended row is badged "active"), and
  `/users/[userPublicId]/addresses` (cards of a user's saved addresses with
  coords and timestamps). A new `Pricing` sidebar item routes to the page; the
  driver-detail header gets a "Saved addresses →" link so the addresses view
  is reachable from the existing flow. Money displayed in ₹ via a small
  `paiseToRupees / rupeesToPaise` helper. Needed a new backend endpoint
  `GET /api/v1/admin/users/:userPublicId/addresses` (delegates to
  `AddressesService.list` after a publicId → bigint lookup) — wired through
  `AddressesModule` import in `AdminModule`.
- **Maps in admin** — reusable `<Map>` component
  ([admin/src/components/map.tsx](../../admin/src/components/map.tsx)) backed
  by Leaflet 1.9 + OSM tiles. Props: `center`, `zoom`, `markers`, `fitBounds`,
  `height`. Leaflet is loaded via dynamic `import('leaflet')` inside `useEffect`
  to stay SSR-safe; consumers wrap it with `next/dynamic({ ssr: false })`. The
  default marker icon URLs are re-pointed at the upstream CDN once on first
  init (otherwise webpack rewrites them to 404 paths). First user: the
  `/users/[userPublicId]/addresses` page renders pins for each saved address
  with auto-fit bounds; Sprint 4–5 will add polylines + driver markers on top
  of the same component.

## Carryover

## Notes / Blockers
