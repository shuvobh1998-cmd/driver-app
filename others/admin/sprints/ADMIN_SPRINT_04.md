# Admin Sprint A04 — Live Map + Ride Requests

> **Duration:** 2 weeks (parallel with Backend Sprint 4)
> **Goal:** Founder opens `/live-map`, sees Postman-scripted drivers as moving pins. Posts a ride request → sees the new request appear in `/rides/requests`.

## Scope

### Pages

- `/live-map` — full-page Leaflet map
  - WebSocket subscription to `driver.location.updated`
  - Filter chips by vehicle type
  - Side panel: counts (online / on-trip per type)
  - Click a driver pin → shows driver info card
- `/rides/requests` — list with filters: status, date range, vehicle type
- `/rides/requests/[id]` — detail: map with pickup/drop pins + polyline, request info, matched trip link
- Dashboard widget: mini-live-map

### Components

- `<DriverPin>` — colored per vehicle type
- `<LiveDriverCounts>` — count chips
- `<WSConnectionStatus>` — visual indicator in topbar
- Hook: `useTripWS(tripId)` for trip rooms (used in Sprint 7)

### Tasks

- Socket.IO client wired with JWT in query
- Client-side throttling: max 1 marker update / second per driver to avoid jitter
- Pin clustering above 50 drivers (react-leaflet-cluster)
- Reconnect with exponential backoff
- Filter persistence in URL query

## Endpoints consumed

- `GET /api/v1/admin/live-map/drivers`
- `GET /api/v1/admin/ride-requests?status=&from=&to=&page=`
- `GET /api/v1/admin/ride-requests/:id`
- WS connection `wss://<backend>/admin` namespace
- WS events: `driver.location.updated`

## Acceptance

- [ ] 3 Postman-scripted drivers visible on map, moving smoothly
- [ ] Filter by AUTO hides BIKE drivers
- [ ] Ride request appears in `/rides/requests` within 5s of POST
- [ ] WS reconnects after network drop (test with airplane mode toggle)

## Git plan

- `feature/admin-a04-ws-client`
- `feature/admin-a04-live-map`
- `feature/admin-a04-driver-pins`
- `feature/admin-a04-ride-requests-list`
- `feature/admin-a04-ride-request-detail`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
