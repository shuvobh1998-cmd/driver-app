# Admin Sprint A07 — Carpool, Bookings, Chat Audit

> **Duration:** 2 weeks (parallel with Backend Sprint 9)
> **Goal:** Founder views a posted Kolkata→Howrah scheduled trip, sees both seat bookings, opens the chat thread between rider and driver.

## Scope

### Pages

- `/scheduled-trips` — list + filter (status, date range, driver)
- `/scheduled-trips/[id]` — detail with:
  - Route map (polyline + origin/destination markers)
  - Posted info (seats, price, departure)
  - Bookings list (each rider's pickup/drop along route)
  - Cancel button (refunds all bookings)
- `/bookings` — all seat bookings
- `/bookings/[id]` — detail
- `/chats` — recent threads (audit, read-only)
- `/chats/[id]` — full thread w/ flag-message action

### Components

- `<RouteMap>` — line with origin/destination + per-rider pickup pins
- `<BookingCard>`
- `<ChatThread>` — bubble layout, system messages, flag button
- `<FlagModal>` — reason + confirm

### Tasks

- Pagination + filters for both scheduled trips and bookings
- Route polyline rendering (decode from server)
- Read-only chat thread w/ search by user
- Flag mutation with optimistic UI

## Endpoints consumed

- `GET /api/v1/admin/scheduled-trips?...`
- `GET /api/v1/admin/scheduled-trips/:id`
- `POST /api/v1/admin/scheduled-trips/:id/cancel`
- `GET /api/v1/admin/bookings?...`
- `GET /api/v1/admin/bookings/:id`
- `GET /api/v1/admin/chats?...`
- `GET /api/v1/admin/chats/:id`
- `POST /api/v1/admin/chats/messages/:id/flag`

## Acceptance

- [ ] Cancel scheduled trip refunds all bookings (verified in payments list)
- [ ] Chat thread loads in order, system messages distinguishable
- [ ] Flag action records audit entry

## Git plan

- `feature/admin-a07-scheduled-trips-list`
- `feature/admin-a07-scheduled-trip-detail`
- `feature/admin-a07-bookings`
- `feature/admin-a07-chats-audit`
- `feature/admin-a07-chat-flag`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
