# Mobile Sprint M02 — Maps, Addresses, Rider Home, Fare Quote

> **Duration:** 2 weeks
> **Goal:** Rider opens app, sees a map with their location, taps "Where to?", types an address, picks from autocomplete, sees fare quotes for all 4 vehicle types side-by-side — but doesn't actually request a ride yet (that's M04).

## Scope

### Screens

- Rider home: full-screen map (`flutter_map`) + "Where to?" bar at top + saved places chips
- Address search (overlay): autocomplete list as user types, recent locations on top
- Pickup confirmation (map with draggable pin + "Set pickup here" button)
- Drop confirmation (same)
- Fare quote sheet: bottom sheet with 4 vehicle type cards (icon, label, fare, ETA to pickup)
- Saved addresses CRUD: list, add, edit, delete (with label HOME/WORK/custom)

### Components

- `MapWidget` — reusable `flutter_map` wrapper
- `AddressAutocomplete` — debounced 300ms
- `VehicleTypeCard` — icon, label, ₹ amount, ETA
- `SavedAddressTile`

### Behavior

- Default map center: user's current GPS location (request permission on first map open)
- Recent locations populated from `/users/me/recent-locations`
- Geocode debounce 300ms client-side
- Fare estimate request only after both pickup + drop set
- Cache fare estimate 60s (don't re-fetch on minor map movement)

## Endpoints integrated

- `GET /api/v1/maps/geocode?q=...`
- `GET /api/v1/maps/reverse-geocode?lat=&lng=`
- `POST /api/v1/maps/route`
- `POST /api/v1/fares/estimate`
- `GET /api/v1/users/me/addresses`
- `POST /api/v1/users/me/addresses`
- `PATCH /api/v1/users/me/addresses/:id`
- `DELETE /api/v1/users/me/addresses/:id`
- `GET /api/v1/users/me/recent-locations`

## Acceptance

- [ ] App requests location permission on first map open
- [ ] Map renders OSM tiles
- [ ] Type "Park Street Kolkata" → list of suggestions in <1s
- [ ] Pick pickup + drop → fare quote sheet shows 4 cards
- [ ] Save a HOME address → next session it appears
- [ ] Map gracefully handles offline (cached tiles for visited area)

## Status

- [x] Backend API delivered (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable for M02 = the backend endpoints + Swagger the Flutter team consumes.
> Most M02 endpoints already shipped in Sprints 1–4; this sprint added the two missing
> pieces and verified the whole set live.

**New this sprint**

- `GET /users/me/recent-locations` — rider's recent pickup/drop points from past ride
  requests (unioned, deduped by address + rounded coords, most-recent-first;
  `?limit` default 10, max 50). Feeds the "recent" rows above autocomplete.
- `POST /fares/estimate-all` — one call returns a fare per priced vehicle type
  (BIKE/AUTO/CNG/CAR) for the 4-card fare quote sheet. Additive; the single-type
  `POST /fares/estimate` (used by the ride-request flow) is unchanged.

**Already live (verified this sprint)**

- `GET /maps/geocode?q=` · `GET /maps/reverse-geocode?lat=&lng=` · `POST /maps/route`
- `GET`/`POST /users/me/addresses`, `PATCH`/`DELETE /users/me/addresses/:id`

**Verification** — booted against the real stack (Supabase PostGIS + Redis + OSRM +
Nominatim) and smoke-tested every endpoint: geocode returns Kolkata suggestions,
route returns distance/duration/polyline, `estimate-all` returns all 4 cards
(single-type AUTO matches the AUTO card), addresses CRUD round-trips, recent-locations
returns 200. 249 unit tests green.

## Notes

- **ETA-to-pickup on the fare cards:** `estimate-all` returns fares only, not
  per-type ETA-to-pickup — an accurate ETA needs the nearest available driver per
  type, which is the matching domain (computed at request time, M04). The card can
  show the fare now and fill ETA when the rider proceeds to request.
- **Fare estimate caching (60s) and geocode debounce (300ms)** are client-side
  concerns per the sprint scope; the backend geocode/route responses are already
  cached server-side in Redis.
- The `/fares/*` and `/maps/*` endpoints require a bearer token (any authenticated
  user). `/app/config` (M01) stays public.
