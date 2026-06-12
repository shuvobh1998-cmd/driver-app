# driver_home

D3 — Go online + location: driver home map, vehicle selector, the big
online/offline toggle, and ~5s background location pings that feed the admin
live-map.

Layers:
- `data/`
  - `driver_state_api.dart` — `POST /drivers/me/online|offline|location`,
    `GET /drivers/me/state`. Every call returns the authoritative `DriverState`.
  - `location_ping_store.dart` — drift-backed queue (the `location_pings` table)
    that buffers pings during a network blip and is drained on the next success.
  - `models/driver_state.dart` — `DriverState`, `DriverLocation`, `DriverStatus`.
  - `driver_home_providers.dart` — API/queue providers + `initialMapCenter`.
- `presentation/`
  - `controllers/driver_home_controller.dart` — the single source of truth for
    online/offline/on-trip. Drives the location pump (subscribe → POST → on
    failure enqueue, on success flush the queue), reconciles against server
    truth, and resumes streaming on relaunch if the server still has us online.
    `driverTransitioningProvider` carries the go-online/offline spinner so the
    map keeps its last position (no flicker).
  - `screens/driver_home_screen.dart` — map + status header + control panel.
  - `widgets/` — `DriverGoOnlineButton`, `DriverMap`, `VehicleSelector`,
    `location_permission_primer` (the "Always" + battery primer sheet).

Location streaming lives in `core/location/live_location_service.dart`: a
position stream (which also powers the Android foreground-service notification
so pings continue when backgrounded) plus a 5s timer that emits a sample from
the latest fix. Manifest/Info.plist carry the background-location + foreground
-service permissions.

Earnings (the "Today · ₹—" chip) is wired in D5. See
`docs/DRIVER_APP_SPRINT_PLAN.md`.
