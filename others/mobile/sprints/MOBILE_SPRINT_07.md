# Mobile Sprint M07 — Scheduled Carpool (Firti Gari) + Chat

> **Duration:** 2 weeks
> **Goal:** Driver posts a Kolkata→Howrah trip for tomorrow morning (3 seats, ₹120/seat). Two riders search "Park Street → Howrah" → both find the trip → both book a seat → both chat the driver about exact pickup location.

## Scope

### Driver screens

- "Post a trip" form: origin, destination, departure date+time, total seats, price/seat, vehicle, notes, preferences (AC, gender)
- My posted trips: list with status (OPEN / FULL / IN_PROGRESS / COMPLETED / CANCELLED)
- Posted trip detail: route map, bookings list (rider photo, pickup, drop), cancel button
- Trip day flow: start trip → rider list with check-in toggles → complete trip
- Mark no-show per booking

### Rider screens

- "Carpool" tab in home
- Search form: pickup, drop, date, time window, seats, optional filters (price max, vehicle type)
- Search results: scrollable list (driver photo, route summary, time, ₹/seat, available seats)
- Trip detail: route map, driver info, pickup along route picker, book button
- My bookings: upcoming + past tabs
- Booking detail: trip info, cancel button (with refund preview)

### Chat (shared)

- Threads list (per booking / scheduled trip)
- Conversation screen: bubble UI, quick replies ("I'm here", "5 min", etc.)
- Send text + system messages (e.g., "Rider booked", "Driver cancelled")
- Live receive via WS

## Endpoints integrated

### Driver

- `POST /api/v1/scheduled-trips`
- `GET /api/v1/scheduled-trips/me`
- `PATCH /api/v1/scheduled-trips/:id`
- `POST /api/v1/scheduled-trips/:id/cancel`
- `GET /api/v1/scheduled-trips/:id/bookings`
- `POST /api/v1/scheduled-trips/:id/start`
- `POST /api/v1/scheduled-trips/:id/complete`
- `POST /api/v1/bookings/:id/no-show`

### Rider

- `GET /api/v1/scheduled-trips/search?...`
- `GET /api/v1/scheduled-trips/:id`
- `POST /api/v1/scheduled-trips/:id/bookings`
- `GET /api/v1/bookings/me`
- `GET /api/v1/bookings/:id`
- `POST /api/v1/bookings/:id/cancel`
- `GET /api/v1/bookings/:id/cancellation-preview`

### Chat

- `POST /api/v1/chats/messages`
- `GET /api/v1/chats/threads`
- `GET /api/v1/chats/threads/:otherUserId/messages`
- `POST /api/v1/chats/threads/:otherUserId/read`
- WS `chat.message.received`

## Acceptance

- [ ] Driver posts trip → rider finds via search
- [ ] 2 riders book same trip → 3rd rider sees "1 seat left"
- [ ] 4th rider tries to book → "TRIP_FULL"
- [ ] Driver cancels → bookings refunded automatically (verified in payments)
- [ ] Chat works in real time (WS), both sides
- [ ] Cancellation refund preview shows correct amount per policy

## Status

- [x] Backend API delivered + verified end-to-end (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable = the backend endpoints + WS events + Swagger the Flutter team
> consumes. New `carpool` + `chat` modules (migration `0019_carpool_chat`).

**Driver — scheduled trips**

- `POST /scheduled-trips` (PostGIS origin/dest; validates owned+approved vehicle,
  future departure, seats ≤ vehicle seats) · `GET /scheduled-trips/me` (status
  filter) · `PATCH /scheduled-trips/:id` (only while OPEN with no bookings) ·
  `POST /scheduled-trips/:id/cancel` (refunds every booking 100%).
- `GET /scheduled-trips/:id/bookings` · `POST /scheduled-trips/:id/start` ·
  `POST /scheduled-trips/:id/complete` · `POST /bookings/:id/no-show`.

**Rider — search & booking**

- `GET /scheduled-trips/search` — both route ends within `radiusMeters` (PostGIS
  `ST_DWithin`), OPEN, seats free, in the date window; sorted by `routeMatchMeters`.
- `GET /scheduled-trips/:id` · `POST /scheduled-trips/:id/bookings` (seat
  decrement under a row lock; flips FULL at zero) · `GET /bookings/me`
  (`filter=upcoming|past`) · `GET /bookings/:id` · `POST /bookings/:id/cancel` ·
  `GET /bookings/:id/cancellation-preview`.

**Chat (shared)**

- `POST /chats/messages` · `GET /chats/threads` (last message + unread per
  counterparty) · `GET /chats/threads/:otherUserId/messages` · `POST
/chats/threads/:otherUserId/read`. WS **`chat.message.received`** to the
  recipient's user room; FCM push (`type=CHAT_MESSAGE`). Booking/cancel post
  **SYSTEM** messages ("New booking…", "Driver cancelled the trip. ₹120 refunded.").

**Seat & refund model.** `available_seats` is denormalized on the trip and moved
inside the booking/cancel transaction (`FOR UPDATE` lock) — OPEN→FULL at zero,
FULL→OPEN when a seat frees (unless already IN_PROGRESS). Refund is the
PLACEHOLDER policy (API plan open question #3): **100% >24h, 50% 12-24h, 0% <12h**
before departure; a **driver-initiated** cancel always refunds **100%**. The
computed `refundAmount` + `paymentStatus=REFUNDED` are stored on the booking.

**End-to-end verification** (real Supabase + Redis): post (3 seats) → search finds
it (`routeMatchMeters=0`) → rider1 + rider2 book → detail shows **1 seat left** →
over-book **422 TRIP_FULL** → re-book same rider **409 DUPLICATE** → last seat →
**FULL**. Chat: rider→driver message, driver `threads` (USER + SYSTEM, unread
counts), driver reads + replies, rider `read` → `{updated:2}`. Cancellation:
preview **100%/₹120** (>24h) → rider cancel refunds + restores seat + FULL→OPEN →
driver cancels trip → all bookings **CANCELLED + refunded 100%** with system
notices. Lifecycle: PATCH before booking ok / after booking **409**, no-show
before start **409**, start→**IN_PROGRESS**→no-show→**NO_SHOW**→**COMPLETED**.
335 unit tests green.

## Notes

- **Cancellation/refund % is a placeholder** (open question #3) — fixed in
  `refund-policy.ts` for now (not env-driven yet); confirm the brackets with the
  founder before launch. Driver-cancel = always 100% is a deliberate choice.
- **Carpool payment collection is not wired to Razorpay** this sprint. A booking
  records `amount` + `paymentStatus` (PENDING→REFUNDED on cancel); actual
  charge/settlement (cash on board, or prepaid via the M06 gateway) is a later
  task. "Refunded automatically" is reflected on the booking, not yet a money
  movement.
- **Search window:** a `date` covers the whole IST day (+`timeWindowHours`
  cushion) so an early-morning trip still surfaces; no `date` → now..+7 days.
  Default match radius 1.5 km on both ends.
- **Gender preference** enforced at booking (`GENDER_NOT_ALLOWED` 403) against the
  rider's stored `gender`; riders with no gender set can't book a restricted trip.
- **Thread model is derived** (grouped by the other user); there's no thread
  entity. `scheduledTripId` is optional context on each message.
- **WS `chat.typing`** (typing indicator, §14.6, optional) is **not** built.
