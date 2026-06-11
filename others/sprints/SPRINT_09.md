# Sprint 9 — Scheduled Carpool (BlaBlaCar Feature)

> **Duration:** 2 weeks
> **Theme:** Driver posts a planned trip, riders search by route corridor, book seats, chat

## Goal

Founder posts a Kolkata→Howrah scheduled trip as a driver (3 seats, ₹120 each). Two riders search "Park Street → Howrah Maidan" tomorrow morning, find this trip, book a seat each, and pay. Founder sees both bookings in admin.

## Why this sprint

This is the **product differentiator** vs Rapido/Uber/Ola. Without it, the app is a worse copy of Uber. With it, the app has a story: "earn back your fuel cost on rides you're already taking."

## Features

### 1. Scheduled trip posting (driver)

- `POST /api/v1/scheduled-trips` — body: `{ origin, destination, departureAt, totalSeats, pricePerSeat, notes? }`
  - Server computes `route_line` via routing API (Sprint 3)
  - Status: OPEN
- `GET /api/v1/scheduled-trips/me` — driver's posted trips
- `PATCH /api/v1/scheduled-trips/:id` — update before any booking exists
- `POST /api/v1/scheduled-trips/:id/cancel` — driver cancels, refunds all booked seats

### 2. Search by route corridor (rider)

- `GET /api/v1/scheduled-trips/search?pickupLat=&pickupLng=&dropLat=&dropLng=&date=&seats=`
  - Returns trips where rider's pickup AND drop are within ~1km of `route_line`
  - PostGIS `ST_DWithin(route_line, pickup_point, 1000) AND ST_DWithin(route_line, drop_point, 1000)`
  - Filter by `departure_at` within ±3h of requested time
  - Filter by `available_seats >= seats`
  - Order by departure time

### 3. Seat booking

- `POST /api/v1/scheduled-trips/:id/bookings` — body: `{ seatsBooked, pickupLocation, dropLocation, paymentMethod }`
  - Atomic check on `available_seats` (row lock)
  - Creates `seat_bookings` row (status=PENDING)
  - For UPI: creates Razorpay order, returns payment payload
  - For CASH: confirms immediately, marks PENDING_CASH (driver collects on day)
  - On payment success → status=CONFIRMED, decrement `available_seats`
- `GET /api/v1/bookings/me` — rider's bookings
- `GET /api/v1/bookings/:id` — detail
- `POST /api/v1/bookings/:id/cancel` — respects cancellation policy (e.g., >24h before = full refund, <24h = 50%)

### 4. Cancellation policy

- Config in `pricing_rules` or new `cancellation_policies` table
- Tiers: e.g., `>24h → 100%`, `12-24h → 50%`, `<12h → 0%`
- Driver cancels → 100% refund to all bookings + driver penalty

### 5. Trip day flow

- On `departure_at`, status auto → IN_PROGRESS (cron job)
- Driver `POST /api/v1/scheduled-trips/:id/start` — locks remaining seats
- Driver `POST /api/v1/scheduled-trips/:id/complete` — releases payments to wallet (one ledger entry per booking)
- No-show handling: driver marks `POST /api/v1/bookings/:id/no-show`

### 6. In-app chat (basic)

- `POST /api/v1/chats/messages` — body: `{ scheduledTripId, toUserId, message }`
- `GET /api/v1/chats/threads` — list of conversations
- `GET /api/v1/chats/threads/:otherUserId/messages` — messages with someone
- WebSocket: `chat.message.received` event
- Scoped to scheduled trips (rider ↔ driver of that trip only)
- Length limit, basic profanity filter optional

### 7. Admin pages

- `/scheduled-trips` — list with filters
- `/scheduled-trips/[id]` — detail with route map, bookings list, cancel button
- `/bookings` — all bookings
- `/chats` — read-only audit of all chats (safety)

### 8. Notifications

- Push to driver on new booking
- Push to all riders on driver cancel
- Push 30 min before departure to both sides

## API endpoints delivered

| Method | Path                                          | Auth     | Purpose               |
| ------ | --------------------------------------------- | -------- | --------------------- |
| POST   | `/api/v1/scheduled-trips`                     | driver   | Post a trip           |
| GET    | `/api/v1/scheduled-trips/me`                  | driver   | My posted trips       |
| PATCH  | `/api/v1/scheduled-trips/:id`                 | driver   | Edit (if no bookings) |
| POST   | `/api/v1/scheduled-trips/:id/cancel`          | driver   | Cancel                |
| POST   | `/api/v1/scheduled-trips/:id/start`           | driver   | Trip day start        |
| POST   | `/api/v1/scheduled-trips/:id/complete`        | driver   | Done, settle          |
| GET    | `/api/v1/scheduled-trips/search`              | rider    | Corridor search       |
| POST   | `/api/v1/scheduled-trips/:id/bookings`        | rider    | Book seat             |
| GET    | `/api/v1/bookings/me`                         | rider    | My bookings           |
| GET    | `/api/v1/bookings/:id`                        | involved | Detail                |
| POST   | `/api/v1/bookings/:id/cancel`                 | rider    | Cancel booking        |
| POST   | `/api/v1/bookings/:id/no-show`                | driver   | Mark no-show          |
| POST   | `/api/v1/chats/messages`                      | bearer   | Send chat             |
| GET    | `/api/v1/chats/threads`                       | bearer   | List threads          |
| GET    | `/api/v1/chats/threads/:otherUserId/messages` | bearer   | Messages              |
| GET    | `/api/v1/admin/scheduled-trips`               | admin    | All scheduled         |
| GET    | `/api/v1/admin/bookings`                      | admin    | All bookings          |
| GET    | `/api/v1/admin/chats`                         | admin    | Audit chats           |

## DB migrations this sprint

1. `0024_scheduled_trips`
2. `0025_seat_bookings`
3. `0026_chat_messages`
4. `0027_cancellation_policies` (if separate table)

## Admin panel pages this sprint

| Page                    | Purpose                 |
| ----------------------- | ----------------------- |
| `/scheduled-trips`      | List + filters          |
| `/scheduled-trips/[id]` | Detail + map + bookings |
| `/bookings`             | All bookings            |
| `/chats`                | Read-only chat audit    |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + WS event + Swagger + Postman. No Flutter code from us. This sprint unblocks the firti gari / BlaBlaCar flow.

**Driver endpoints shipped:**

- `POST /api/v1/scheduled-trips` — post a trip
- `GET /api/v1/scheduled-trips/me`
- `PATCH /api/v1/scheduled-trips/:id` (edit before any booking)
- `POST /api/v1/scheduled-trips/:id/cancel`
- `POST /api/v1/scheduled-trips/:id/start`
- `POST /api/v1/scheduled-trips/:id/complete`
- `POST /api/v1/bookings/:id/no-show`

**Rider endpoints shipped:**

- `GET /api/v1/scheduled-trips/search?pickupLat=&pickupLng=&dropLat=&dropLng=&date=&seats=` — PostGIS corridor search
- `POST /api/v1/scheduled-trips/:id/bookings`
- `GET /api/v1/bookings/me`, `/bookings/:id`
- `POST /api/v1/bookings/:id/cancel`

**Chat endpoints shipped:**

- `POST /api/v1/chats/messages`
- `GET /api/v1/chats/threads`
- `GET /api/v1/chats/threads/:otherUserId/messages`

**WebSocket events shipped:**

- `chat.message.received` — `{ threadId, fromUserId, message, sentAt }` → recipient
- `scheduledTrip.booked` — `{ tripId, bookingId, rider }` → driver
- `scheduledTrip.cancelled` — `{ tripId, by, reason }` → affected party

**Conventions Flutter must match:**

- Date format on search: ISO 8601 (`2026-06-15`); time window is ±3h around driver's `departureAt`
- Seats are integers; atomic check happens server-side (concurrent bookings safe)
- Cancellation policy returned in booking response so Flutter can display refund preview
- Chat is scoped to actual booking participants only — backend enforces, but Flutter should hide chat icon for non-participants

**Artifacts:**

- Postman collection: `docs/postman/sprint-09.json`

**Unblocks mobile sprint M07 (firti gari + chat)** — post-trip form, search/book carpool, chat UI. See [`docs/mobile/sprints/MOBILE_SPRINT_07.md`](../mobile/sprints/MOBILE_SPRINT_07.md).

## Demo checklist

- [ ] Founder (as driver) posts a Kolkata→Howrah trip, 3 seats, ₹120
- [ ] Rider A searches "Park Street → Howrah" tomorrow morning → finds the trip
- [ ] Rider A books 1 seat, pays via Razorpay test
- [ ] Rider B does same, books 2 seats
- [ ] Founder sees driver's trip showing FULL in admin
- [ ] Rider A chats driver "where exactly to meet" — driver replies
- [ ] Founder cancels the trip → both riders refunded automatically

## Definition of Done

- [ ] Corridor search returns correct matches (verified with PostGIS query unit test)
- [ ] Atomic seat booking: 5 concurrent bookings for last 1 seat → only 1 succeeds
- [ ] Cancellation policy correctly prorates refunds
- [ ] Auto-status update via cron job tested
- [ ] Chat scoped to actual booking participants only
- [ ] Driver cancel triggers refund + push to all riders
- [ ] Git tag `v0.9.0-sprint-9`

## Git plan

- `feature/sprint-9-scheduled-trip-post`
- `feature/sprint-9-corridor-search`
- `feature/sprint-9-seat-booking`
- `feature/sprint-9-cancellation-policy`
- `feature/sprint-9-trip-day-flow`
- `feature/sprint-9-chat`
- `feature/sprint-9-admin-scheduled`
- `feature/sprint-9-departure-cron`

## Status

- [ ] Not started

## Delivered

## Carryover

## Notes / Blockers
