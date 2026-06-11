# Realtime (Socket.IO) Event Vocabulary — LOCKED

> Sprint 7 Feature 8. This is the **locked** contract between the backend gateway
> and the mobile/admin clients. Event names and payload shapes here are stable —
> change them only with a version bump and a note in the sprint log.
>
> Source of truth: `backend/src/realtime/realtime.gateway.ts`.

## Connection

The Socket.IO server is attached to the same HTTP server as the API, mounted at
the **host root** (not under `/api/v1`). Example: if the API is
`https://api.example.com/api/v1`, the socket connects to `https://api.example.com`.

Authenticate on connect with a JWT **access token** (the same token used for the
REST API). The gateway accepts it three ways, checked in order:

1. `auth.token` in the handshake (preferred)
2. `token` query parameter
3. `Authorization: Bearer <token>` header

A bad or missing token gets an `error` event then an immediate disconnect.

### Rooms

On a successful handshake the socket auto-joins:

- `user:<id>` — the authenticated user (rider or driver). Direct targeting.
- `role:ADMIN` — admins/support only. Fan-out for the live map.

Per-trip rooms (`trip:<tripId>`) are **opt-in** via `trip.subscribe` (see below).

### Client connection example (JS / `socket.io-client`)

```ts
import { io } from 'socket.io-client';

const socket = io('https://api.example.com', {
  auth: { token: accessToken },
  transports: ['websocket'],
});

socket.on('connect', () => console.log('connected'));
socket.on('error', (e) => console.warn('ws error', e)); // { code, message }
```

### Client connection example (Flutter / `socket_io_client`)

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io('https://api.example.com', <String, dynamic>{
  'transports': ['websocket'],
  'auth': {'token': accessToken},
});

socket.onConnect((_) => print('connected'));
socket.on('error', (e) => print('ws error: $e'));
```

---

## Server → client events

All `tripId`, `rideRequestId`, `offerId` values are public ids (`trp_*`, `req_*`,
`off_*`). Timestamps are ISO-8601 UTC strings. Money is integer **paise**.

### Matching (Sprint 4)

| Event                     | Sent to                                    | Payload                                                                                    |
| ------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------ |
| `trip.offered`            | the offered **driver** (`user:<driverId>`) | `{ offerId, rideRequestId, vehicleType, pickup: { lat, lng }, distanceMeters, expiresAt }` |
| `trip.matched`            | the **rider** (`user:<riderId>`)           | `{ rideRequestId, tripId, startOtp }`                                                      |
| `driver.location.updated` | **admins** (`role:ADMIN`)                  | `{ driverUserId, vehicleType, lat, lng, speed?, bearing?, at }`                            |

> `trip.matched.startOtp` is the 4-digit **trip start OTP** (Feature 4). It is sent
> only to the rider. The rider shows it to the driver, who submits it on start.

### Trip lifecycle (Sprint 7) — LOCKED

All four go to the **rider + driver + admins** for that trip.

| Event                 | Payload                                                                                          |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| `trip.status.changed` | `{ tripId, status, at }` — `status` is one of `ACCEPTED · ARRIVED · STARTED · ENDED · CANCELLED` |
| `trip.driver.arrived` | `{ tripId, at }`                                                                                 |
| `trip.completed`      | `{ tripId, summary: { totalFare, distanceMeters, durationSeconds } }`                            |
| `trip.cancelled`      | `{ tripId, by, reason, at }` — `by` is `RIDER · DRIVER · SYSTEM · ADMIN`                         |

`trip.status.changed` fires on **every** transition; the specific events
(`trip.driver.arrived`, `trip.completed`, `trip.cancelled`) fire alongside it so a
client can either switch on status or listen for the specific moment.

### Live location (Sprint 7) — LOCKED

| Event                   | Sent to                        | Payload                                                            |
| ----------------------- | ------------------------------ | ------------------------------------------------------------------ |
| `trip.location.updated` | subscribers of `trip:<tripId>` | `{ tripId, location: { lat, lng }, recordedAt, speed?, bearing? }` |
| `trip.subscribed`       | the subscribing socket only    | `{ tripId }` (ack of a successful `trip.subscribe`)                |
| `error`                 | the offending socket only      | `{ code, message }`                                                |

`error` codes you may receive: `UNAUTHENTICATED`, `VALIDATION_ERROR`, `FORBIDDEN`.

---

## Client → server events (Sprint 7) — LOCKED

| Event              | Who                    | Payload                                  | Effect                                                                                                                                                                                                                              |
| ------------------ | ---------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `trip.subscribe`   | rider / driver / admin | `{ tripId }`                             | Join `trip:<tripId>` to receive `trip.location.updated`. Access is checked; non-party non-admins get `error` `FORBIDDEN`. Acked with `trip.subscribed`.                                                                             |
| `trip.unsubscribe` | any subscriber         | `{ tripId }`                             | Leave the trip room.                                                                                                                                                                                                                |
| `trip.location`    | the trip's **driver**  | `{ tripId, lat, lng, speed?, bearing? }` | Stream the driver's position. Validated (must own an active trip), **rate-limited to 1 / 2s / driver** (excess pings are silently dropped), fanned out as `trip.location.updated`, and sampled (1 in 5) into `trip_location_pings`. |

A trip is "active" (driver may stream) while it is `ACCEPTED`, `ARRIVED`, or
`STARTED`. After `ENDED`/`CANCELLED` the driver stream is rejected with `error`
`FORBIDDEN`.

Disconnecting does **not** change trip state — the trip stays active and the last
persisted location holds. Socket.IO removes the socket from its rooms.

---

## Trip start OTP — UX flow (Feature 4)

1. Driver accepts the offer → backend generates a 4-digit `startOtp` and emits
   `trip.matched` (with `startOtp`) to the **rider** only. The rider can also read
   it from `GET /api/v1/trips/:id` (returned to the rider, before the trip starts).
2. The **rider app displays the code.** The driver does **not** receive it.
3. Driver reaches pickup → `POST /api/v1/trips/:id/arrived`.
4. Rider reads the code aloud / shows the screen; the **driver enters it** →
   `POST /api/v1/trips/:id/start` with body `{ "otp": "1234" }`.
   - Missing → `400 OTP_REQUIRED`. Wrong → `409 OTP_INVALID`.
5. On success the trip moves to `STARTED` and `trip.status.changed` fires.

This proves the rider is physically present before the meter starts.

---

## Typical trip timeline over the socket

```
rider socket                          driver socket                 admin socket
  │  trip.matched {startOtp}            │ trip.offered                 │
  │  trip.subscribe ──────────────────▶ │ (HTTP accept)                │
  │                                     │ trip.location ──────────────▶│ (joins trip room)
  │  trip.driver.arrived ◀──────────────┼──────────────────────────────│
  │  trip.status.changed (STARTED) ◀────┼── (HTTP start + otp) ─────────│
  │  trip.location.updated ◀────────────┼── trip.location ──────────────│  (every ≤2s)
  │  trip.completed ◀───────────────────┼── (HTTP end) ─────────────────│
```
