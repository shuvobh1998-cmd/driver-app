# Mobile App — Complete API Architecture

> **Single source of truth for the Flutter team.** A-to-Z spec of every feature an Indian ride-sharing app needs (Rapido + Uber + BlaBlaCar / firti gari combined). Each endpoint tagged with the sprint that delivers it.

---

## How to use this doc

- **Flutter devs:** find your screen → see the exact endpoint, payload, status tag.
- **Backend engineer:** use the "needed in" tag to plan which endpoint lands in which sprint.
- **Founder / PM:** scan the domain headings to see the full feature surface.

### Status legend

| Tag | Meaning                                                                                |
| --- | -------------------------------------------------------------------------------------- |
| ✅  | Live now (in `main`, will work once Fly.io deploy is green)                            |
| 🔧  | Coming in **Sprint 5** (mobile auth — see [SPRINT_05](sprints/SPRINT_05.md))           |
| 🛟  | Coming in **Sprint 6** (safety, SOS, deletion — see [SPRINT_06](sprints/SPRINT_06.md)) |
| ⏳  | Coming in **Sprint 7** (trip lifecycle + ratings)                                      |
| 💰  | Coming in **Sprint 8** (payments + wallet)                                             |
| 🚗  | Coming in **Sprint 9** (scheduled carpool)                                             |
| 🔔  | Coming in **Sprint 10** (notifications + support)                                      |

---

## 1. Architecture overview

```
┌──────────────────────────────────────────────────────────────────┐
│  Flutter app (rider + driver in one binary, role-aware)           │
│  • dio HTTP client w/ auth interceptor + 401 auto-refresh         │
│  • socket_io_client w/ JWT in query                               │
│  • flutter_secure_storage for refresh token                       │
│  • firebase_messaging for FCM push                                │
│  • razorpay_flutter for UPI/card                                  │
│  • flutter_map (OSM) — switch to google_maps_flutter later        │
└──────────────────────────────────────────────────────────────────┘
                 │ HTTPS (REST + WSS)
                 ▼
┌──────────────────────────────────────────────────────────────────┐
│  NestJS + Fastify backend on Fly.io (Singapore)                   │
│  Postgres + PostGIS (Supabase) │ Redis Cloud │ BullMQ workers     │
│  Firebase Auth (OTP) │ FCM (push) │ Razorpay (payments)           │
│  Cloudinary (file storage) │ Sentry (errors)                      │
└──────────────────────────────────────────────────────────────────┘
```

### Endpoints under one root

- Base URL (dev): `https://rideshare-backend-dev.fly.dev/api/v1`
- WebSocket: `wss://rideshare-backend-dev.fly.dev`
- Swagger: `https://rideshare-backend-dev.fly.dev/docs`

### Conventions (apply to every endpoint — don't repeat per row)

- `Authorization: Bearer <accessToken>` on every endpoint except those marked public
- Money is integer **paise** (₹100 = 10000)
- Locations as `{lat, lng}` objects, never `[lng, lat]` arrays
- Timestamps ISO 8601 UTC strings
- `Idempotency-Key: <uuid>` header on every money/state-changing POST
- Errors: `{success: false, error: {code, message, field?}}` — switch on `code`
- Pagination: `?page=1&pageSize=20`, max `100`

---

## 2. Identity & Auth

### 2.1 Signup (new user)

| #        | Use                                                                | Endpoint                  | Method | Auth         |
| -------- | ------------------------------------------------------------------ | ------------------------- | ------ | ------------ |
| 2.1.1 🔧 | Start signup, send OTP                                             | `/auth/signup/start`      | POST   | public       |
| 2.1.2 🔧 | Verify OTP, get signup token                                       | `/auth/signup/verify-otp` | POST   | public       |
| 2.1.3 🔧 | Complete signup (name, email, gender, password, emergency contact) | `/auth/signup/complete`   | POST   | signup-token |

### 2.2 Login (returning user)

| #        | Use                                           | Endpoint                              | Method | Auth          |
| -------- | --------------------------------------------- | ------------------------------------- | ------ | ------------- |
| 2.2.1 🔧 | Phone + password login                        | `/auth/login`                         | POST   | public        |
| 2.2.2 ✅ | OTP login fallback (legacy / no password set) | `/auth/otp/send` + `/auth/otp/verify` | POST   | public        |
| 2.2.3 ✅ | Refresh access token                          | `/auth/refresh`                       | POST   | refresh-token |
| 2.2.4 ✅ | Logout this device                            | `/auth/logout`                        | POST   | bearer        |
| 2.2.5 🔧 | Logout from all other devices                 | `/auth/logout/all-others`             | POST   | bearer        |
| 2.2.6 ✅ | Current user                                  | `/auth/me`                            | GET    | bearer        |

### 2.3 Password recovery / management

| #        | Use                                         | Endpoint                        | Method | Auth         |
| -------- | ------------------------------------------- | ------------------------------- | ------ | ------------ |
| 2.3.1 🔧 | Forgot password — request OTP               | `/auth/password/forgot/request` | POST   | public       |
| 2.3.2 🔧 | Forgot password — submit OTP + new password | `/auth/password/forgot/reset`   | POST   | reset-ticket |
| 2.3.3 🔧 | Change password (logged in)                 | `/auth/password/change`         | POST   | bearer       |
| 2.3.4 🔧 | Set password (for OTP-only legacy users)    | `/auth/password/set`            | POST   | bearer       |

### 2.4 Role upgrade

| #        | Use                 | Endpoint                      | Method | Auth  |
| -------- | ------------------- | ----------------------------- | ------ | ----- |
| 2.4.1 🔧 | Rider → also driver | `/users/me/upgrade-to-driver` | POST   | rider |

### 2.5 Device sessions

| #        | Use                            | Endpoint                 | Method | Auth   |
| -------- | ------------------------------ | ------------------------ | ------ | ------ |
| 2.5.1 🔧 | List active sessions / devices | `/users/me/sessions`     | GET    | bearer |
| 2.5.2 🔧 | Revoke a session               | `/users/me/sessions/:id` | DELETE | bearer |

---

## 3. User profile, preferences, settings

| #      | Use                                                         | Endpoint                                  | Method           | Auth   |
| ------ | ----------------------------------------------------------- | ----------------------------------------- | ---------------- | ------ |
| 3.1 ✅ | Get profile                                                 | `/users/me/profile`                       | GET              | bearer |
| 3.2 ✅ | Edit profile (name, email, DOB, gender, emergency contact)  | `/users/me/profile`                       | PATCH            | bearer |
| 3.3 ✅ | Upload avatar                                               | `/users/me/avatar`                        | POST (multipart) | bearer |
| 3.4 🛟 | Update preferences (language, marketing pushes, sms opt-in) | `/users/me/preferences`                   | PATCH            | bearer |
| 3.5 🛟 | Read preferences                                            | `/users/me/preferences`                   | GET              | bearer |
| 3.6 🛟 | Account deletion request (GDPR-style soft delete after 30d) | `/users/me/account/delete-request`        | POST             | bearer |
| 3.7 🛟 | Cancel pending deletion                                     | `/users/me/account/delete-request/cancel` | POST             | bearer |
| 3.8 🛟 | Request data export (email link in 24h)                     | `/users/me/account/data-export`           | POST             | bearer |

**Preferences payload:**

```json
{
  "language": "en" | "bn" | "hi",
  "marketingPush": true,
  "marketingSms": false,
  "marketingEmail": true,
  "tripPushSound": true
}
```

---

## 4. Driver KYC & vehicle onboarding

| #       | Use                                                           | Endpoint                         | Method           | Auth   |
| ------- | ------------------------------------------------------------- | -------------------------------- | ---------------- | ------ |
| 4.1 ✅  | Create driver profile (DOB, emergency contact, etc.)          | `/drivers/me/profile`            | POST             | bearer |
| 4.2 ✅  | Read driver profile                                           | `/drivers/me/profile`            | GET              | driver |
| 4.3 ✅  | Update driver profile                                         | `/drivers/me/profile`            | PATCH            | driver |
| 4.4 ✅  | Upload KYC doc (AADHAAR / DL / PAN / RC / INSURANCE / PERMIT) | `/drivers/me/kyc/documents`      | POST (multipart) | driver |
| 4.5 ✅  | List my KYC docs                                              | `/drivers/me/kyc/documents`      | GET              | driver |
| 4.6 ✅  | Delete a KYC doc (before approval)                            | `/drivers/me/kyc/documents/:id`  | DELETE           | driver |
| 4.7 ✅  | KYC status summary (overall + per-doc)                        | `/drivers/me/kyc/status`         | GET              | driver |
| 4.8 ✅  | Add vehicle                                                   | `/drivers/me/vehicles`           | POST             | driver |
| 4.9 ✅  | List my vehicles                                              | `/drivers/me/vehicles`           | GET              | driver |
| 4.10 ✅ | Update vehicle                                                | `/drivers/me/vehicles/:id`       | PATCH            | driver |
| 4.11 ✅ | Soft-delete vehicle                                           | `/drivers/me/vehicles/:id`       | DELETE           | driver |
| 4.12 ✅ | Upload vehicle photo                                          | `/drivers/me/vehicles/:id/photo` | POST (multipart) | driver |
| 4.13 💰 | Set payout method (UPI / bank)                                | `/drivers/me/payout-method`      | PUT              | driver |
| 4.14 💰 | Read payout method                                            | `/drivers/me/payout-method`      | GET              | driver |

---

## 5. Maps, places & geocoding

| #      | Use                                                       | Endpoint                          | Method | Auth   |
| ------ | --------------------------------------------------------- | --------------------------------- | ------ | ------ |
| 5.1 ✅ | Forward geocode / autocomplete                            | `/maps/geocode?q=...`             | GET    | bearer |
| 5.2 ✅ | Reverse geocode                                           | `/maps/reverse-geocode?lat=&lng=` | GET    | bearer |
| 5.3 ✅ | Route between two points                                  | `/maps/route`                     | POST   | bearer |
| 5.4 ✅ | List saved addresses                                      | `/users/me/addresses`             | GET    | bearer |
| 5.5 ✅ | Save address (HOME / WORK / custom)                       | `/users/me/addresses`             | POST   | bearer |
| 5.6 ✅ | Update saved address                                      | `/users/me/addresses/:id`         | PATCH  | bearer |
| 5.7 ✅ | Delete saved address                                      | `/users/me/addresses/:id`         | DELETE | bearer |
| 5.8 ✅ | Recent locations (auto-populated from past ride requests) | `/users/me/recent-locations`      | GET    | bearer |

---

## 6. Fare engine

| #       | Use                                                                                            | Endpoint                      | Method | Auth   |
| ------- | ---------------------------------------------------------------------------------------------- | ----------------------------- | ------ | ------ |
| 6.1 ✅  | Estimate fare for all vehicle types at once (one call returns BIKE/AUTO/CNG/CAR fares)         | `/fares/estimate-all`         | POST   | bearer |
| 6.1b ✅ | Estimate fare for a single chosen vehicle type (used by the ride-request flow)                 | `/fares/estimate`             | POST   | bearer |
| 6.2 ⏳  | Compute cancellation fee preview                                                               | `/fares/cancellation-preview` | POST   | bearer |
| 6.3 ⏳  | Get a fare lock token (optional, ensures the fare doesn't change between estimate and request) | `/fares/lock`                 | POST   | bearer |

**`/fares/estimate-all` request:**

```json
{ "origin": {"lat":..., "lng":...}, "destination": {"lat":..., "lng":...} }
```

**Response (one call, all priced vehicle types):**

```json
{
  "estimatedDistance": 8400,
  "estimatedDuration": 1320,
  "options": [
    { "vehicleType": "BIKE", "estimatedFare": 8500, "breakdown": {...} },
    { "vehicleType": "AUTO", "estimatedFare": 14500, "breakdown": {...} },
    { "vehicleType": "CNG",  "estimatedFare": 13500, "breakdown": {...} },
    { "vehicleType": "CAR",  "estimatedFare": 22000, "breakdown": {...} }
  ]
}
```

> **`etaToPickupSec` is not returned by `/fares/estimate-all`.** Per-type ETA-to-pickup
> needs the nearest available driver and is computed at request time (matching, M04).
> `/fares/estimate` takes the same body **plus** `"vehicleType"` and returns the single
> `{ estimatedFare, breakdown, estimatedDistance, estimatedDuration }`.

---

## 7. On-demand booking — rider side (Rapido / Uber style)

| #       | Use                                       | Endpoint / WS                                   | Method | Auth  |
| ------- | ----------------------------------------- | ----------------------------------------------- | ------ | ----- |
| 7.1 ✅  | Request a ride                            | `/rides/request`                                | POST   | rider |
| 7.2 ✅  | Poll request status (fallback to WS)      | `/rides/requests/:id`                           | GET    | rider |
| 7.3 ✅  | Cancel request before driver match        | `/rides/requests/:id/cancel`                    | POST   | rider |
| 7.4 ⏳  | Cancel after match / arrive (charges fee) | `/trips/:id/cancel`                             | POST   | rider |
| 7.5 ⏳  | Get current trip                          | `/trips/me/current`                             | GET    | rider |
| 7.6 ⏳  | Trip detail                               | `/trips/:id`                                    | GET    | rider |
| 7.7 ⏳  | Trip history                              | `/trips/me`                                     | GET    | rider |
| 7.8 ⏳  | Trip status changes                       | WS `trip.status.changed`                        | sub    | rider |
| 7.9 ⏳  | Live driver location during trip          | WS `driver.location.updated` (room `trip:{id}`) | sub    | rider |
| 7.10 ⏳ | Driver arrived event                      | WS `trip.driver.arrived`                        | sub    | rider |
| 7.11 ⏳ | Trip completed event                      | WS `trip.completed`                             | sub    | rider |
| 7.12 ⏳ | Rate driver                               | `/trips/:id/rate-driver`                        | POST   | rider |
| 7.13 ⏳ | Report problem with a trip                | `/trips/:id/report`                             | POST   | rider |

**Request body:**

```json
{
  "pickupLocation": {"lat":..., "lng":...},
  "pickupAddress": "B-12 Park Street",
  "dropLocation": {"lat":..., "lng":...},
  "dropAddress": "Howrah Maidan",
  "vehicleType": "AUTO",
  "paymentMethod": "UPI",
  "fareLockToken": "..." ,
  "notes": "Bring helmet"
}
```

---

## 8. On-demand fulfillment — driver side

| #       | Use                                        | Endpoint / WS                         | Method | Auth   |
| ------- | ------------------------------------------ | ------------------------------------- | ------ | ------ |
| 8.1 ✅  | Go online with selected vehicle            | `/drivers/me/online`                  | POST   | driver |
| 8.2 ✅  | Go offline                                 | `/drivers/me/offline`                 | POST   | driver |
| 8.3 ✅  | Send location ping (every 5s while online) | `/drivers/me/location`                | POST   | driver |
| 8.4 ✅  | Current driver state                       | `/drivers/me/state`                   | GET    | driver |
| 8.5 ✅  | Receive trip offer                         | WS `trip.offered` (driver ns)         | sub    | driver |
| 8.6 ✅  | Accept trip offer                          | `/drivers/me/trip-offers/:id/accept`  | POST   | driver |
| 8.7 ✅  | Decline trip offer                         | `/drivers/me/trip-offers/:id/decline` | POST   | driver |
| 8.8 ⏳  | Mark arrived at pickup                     | `/trips/:id/arrived`                  | POST   | driver |
| 8.9 ⏳  | Start trip (enter rider's OTP)             | `/trips/:id/start`                    | POST   | driver |
| 8.10 ⏳ | End trip                                   | `/trips/:id/end`                      | POST   | driver |
| 8.11 ⏳ | Mark cash collected                        | `/trips/:id/payment/cash-collected`   | POST   | driver |
| 8.12 ⏳ | Rate rider                                 | `/trips/:id/rate-rider`               | POST   | driver |
| 8.13 ⏳ | My trip history                            | `/drivers/me/trips`                   | GET    | driver |
| 8.14 ⏳ | My current trip                            | `/drivers/me/trips/current`           | GET    | driver |
| 8.15 ⏳ | Daily earnings summary                     | `/drivers/me/earnings/today`          | GET    | driver |
| 8.16 ⏳ | Weekly earnings summary                    | `/drivers/me/earnings/this-week`      | GET    | driver |

---

## 9. Trip lifecycle — shared real-time

State machine:

```
REQUESTED → ACCEPTED → ARRIVED → STARTED → ENDED
                ↓         ↓         ↓
           CANCELLED  CANCELLED  CANCELLED
```

WebSocket events (all on `wss://.../`, JWT in query, room `trip:{tripId}`):

| Event                        | Audience            | Payload                                              |
| ---------------------------- | ------------------- | ---------------------------------------------------- |
| `trip.offered` ✅            | driver              | `{ offerId, tripPreview, expiresAt }`                |
| `trip.matched` ✅            | rider               | `{ tripId, driver, vehicle, etaSec }`                |
| `trip.status.changed` ⏳     | both                | `{ tripId, status, at }`                             |
| `trip.driver.arrived` ⏳     | rider               | `{ tripId, at }`                                     |
| `driver.location.updated` ⏳ | rider (during trip) | `{ tripId, location, recordedAt, speed?, bearing? }` |
| `trip.completed` ⏳          | both                | `{ tripId, summary }`                                |
| `trip.cancelled` ⏳          | both                | `{ tripId, by, reason, at }`                         |

---

## 10. Payments — rider

| #       | Use                                       | Endpoint                                    | Method | Auth  |
| ------- | ----------------------------------------- | ------------------------------------------- | ------ | ----- |
| 10.1 💰 | Create Razorpay order for a trip          | `/trips/:id/payment/order`                  | POST   | rider |
| 10.2 💰 | Verify Razorpay signature client-returned | `/trips/:id/payment/verify`                 | POST   | rider |
| 10.3 💰 | Save payment method (tokenize UPI / card) | `/users/me/payment-methods`                 | POST   | rider |
| 10.4 💰 | List saved payment methods                | `/users/me/payment-methods`                 | GET    | rider |
| 10.5 💰 | Delete saved payment method               | `/users/me/payment-methods/:id`             | DELETE | rider |
| 10.6 💰 | Set default payment method                | `/users/me/payment-methods/:id/set-default` | POST   | rider |
| 10.7 💰 | Trip invoice (JSON)                       | `/trips/:id/invoice`                        | GET    | rider |
| 10.8 💰 | Trip invoice (PDF)                        | `/trips/:id/invoice.pdf`                    | GET    | rider |

---

## 11. Driver wallet & payouts

| #       | Use                | Endpoint                      | Method | Auth   |
| ------- | ------------------ | ----------------------------- | ------ | ------ |
| 11.1 💰 | Wallet balance     | `/drivers/me/wallet`          | GET    | driver |
| 11.2 💰 | Ledger (paginated) | `/drivers/me/wallet/ledger`   | GET    | driver |
| 11.3 💰 | Request payout     | `/drivers/me/payouts/request` | POST   | driver |
| 11.4 💰 | List my payouts    | `/drivers/me/payouts`         | GET    | driver |
| 11.5 💰 | Get payout detail  | `/drivers/me/payouts/:id`     | GET    | driver |

---

## 12. Scheduled carpool — "firti gari" — driver side (BlaBlaCar)

| #       | Use                           | Endpoint                        | Method | Auth   |
| ------- | ----------------------------- | ------------------------------- | ------ | ------ |
| 12.1 🚗 | Post a planned trip           | `/scheduled-trips`              | POST   | driver |
| 12.2 🚗 | My posted trips               | `/scheduled-trips/me`           | GET    | driver |
| 12.3 🚗 | Update (only if no bookings)  | `/scheduled-trips/:id`          | PATCH  | driver |
| 12.4 🚗 | Cancel (refunds all bookings) | `/scheduled-trips/:id/cancel`   | POST   | driver |
| 12.5 🚗 | View bookings on my trip      | `/scheduled-trips/:id/bookings` | GET    | driver |
| 12.6 🚗 | Start trip day                | `/scheduled-trips/:id/start`    | POST   | driver |
| 12.7 🚗 | Complete & settle payments    | `/scheduled-trips/:id/complete` | POST   | driver |
| 12.8 🚗 | Mark booking as no-show       | `/bookings/:id/no-show`         | POST   | driver |

**Post-trip payload:**

```json
{
  "origin": {"lat":..., "lng":..., "address":"..."},
  "destination": {"lat":..., "lng":..., "address":"..."},
  "departureAt": "2026-06-10T08:30:00Z",
  "vehicleId": "veh_abc",
  "totalSeats": 3,
  "pricePerSeat": 12000,
  "notes": "AC car, no smoking. Door pickup near Park Street.",
  "preferences": {
    "ac": true,
    "gender": "ANY"
  }
}
```

---

## 13. Scheduled carpool — rider side

| #       | Use                                       | Endpoint                             | Method | Auth  |
| ------- | ----------------------------------------- | ------------------------------------ | ------ | ----- |
| 13.1 🚗 | Search carpools by route + date + filters | `/scheduled-trips/search`            | GET    | rider |
| 13.2 🚗 | View trip detail                          | `/scheduled-trips/:id`               | GET    | rider |
| 13.3 🚗 | Book seats                                | `/scheduled-trips/:id/bookings`      | POST   | rider |
| 13.4 🚗 | My bookings                               | `/bookings/me`                       | GET    | rider |
| 13.5 🚗 | Booking detail                            | `/bookings/:id`                      | GET    | rider |
| 13.6 🚗 | Cancel booking                            | `/bookings/:id/cancel`               | POST   | rider |
| 13.7 🚗 | Cancellation refund preview               | `/bookings/:id/cancellation-preview` | GET    | rider |

**Search query params:**

- `pickupLat`, `pickupLng`, `dropLat`, `dropLng`
- `date` (YYYY-MM-DD), `timeWindowHours` (default 3)
- `seats` (default 1)
- `vehicleType` (filter)
- `priceMax` (paise)
- `sort` = `departure_at` | `price` | `distance_from_route`

---

## 14. Chat & messaging (scheduled carpool first, on-demand later)

| #       | Use                         | Endpoint / WS                          | Method  | Auth   |
| ------- | --------------------------- | -------------------------------------- | ------- | ------ |
| 14.1 🚗 | Send message                | `/chats/messages`                      | POST    | bearer |
| 14.2 🚗 | List threads                | `/chats/threads`                       | GET     | bearer |
| 14.3 🚗 | Read messages in a thread   | `/chats/threads/:otherUserId/messages` | GET     | bearer |
| 14.4 🚗 | Mark messages read          | `/chats/threads/:otherUserId/read`     | POST    | bearer |
| 14.5 🚗 | Live receive                | WS `chat.message.received`             | sub     | bearer |
| 14.6 🚗 | Typing indicator (optional) | WS `chat.typing`                       | pub/sub | bearer |

**Send body:**

```json
{
  "scheduledTripId": "sch_abc",
  "toUserId": "usr_def",
  "message": "Where exactly should I wait?"
}
```

Quick replies (client-side suggestions): "I'm here", "5 minutes", "Where are you?", "Cancel".

---

## 15. Notifications

| #       | Use                       | Endpoint                      | Method | Auth   |
| ------- | ------------------------- | ----------------------------- | ------ | ------ |
| 15.1 🔔 | Register FCM token        | `/users/me/device-tokens`     | POST   | bearer |
| 15.2 🔔 | Unregister FCM token      | `/users/me/device-tokens`     | DELETE | bearer |
| 15.3 🔔 | List in-app notifications | `/notifications`              | GET    | bearer |
| 15.4 🔔 | Mark one read             | `/notifications/:id/read`     | POST   | bearer |
| 15.5 🔔 | Mark all read             | `/notifications/read-all`     | POST   | bearer |
| 15.6 🔔 | Unread count badge        | `/notifications/unread-count` | GET    | bearer |
| 15.7 🔔 | WS live notification      | WS `notification.received`    | sub    | bearer |

### Notification types (FCM data payload always includes `type` for deep-linking)

| Type                                 | Audience                 | Channel                     | Deep link            |
| ------------------------------------ | ------------------------ | --------------------------- | -------------------- |
| `KYC_APPROVED`                       | driver                   | push + inapp                | /driver/home         |
| `KYC_REJECTED`                       | driver                   | push + inapp                | /driver/kyc          |
| `TRIP_OFFERED`                       | driver                   | push + ws                   | /driver/offer/:id    |
| `TRIP_ACCEPTED`                      | rider                    | push                        | /rider/trip/:id      |
| `TRIP_DRIVER_ARRIVED`                | rider                    | push                        | /rider/trip/:id      |
| `TRIP_STARTED`                       | both                     | push                        | /trip/:id            |
| `TRIP_ENDED`                         | both                     | push                        | /trip/:id/summary    |
| `TRIP_CANCELLED`                     | both                     | push                        | /trip/:id            |
| `PAYMENT_SUCCESS`                    | rider                    | push + inapp                | /rider/trip/:id      |
| `PAYMENT_FAILED`                     | rider                    | push + inapp                | /rider/trip/:id      |
| `PAYOUT_PROCESSED`                   | driver                   | push + sms                  | /driver/wallet       |
| `SCHEDULED_TRIP_BOOKED`              | driver                   | push + inapp                | /carpool/trip/:id    |
| `SCHEDULED_TRIP_CANCELLED_BY_DRIVER` | rider                    | push + sms                  | /carpool/booking/:id |
| `DEPARTURE_REMINDER`                 | both                     | push                        | /carpool/trip/:id    |
| `CHAT_MESSAGE`                       | recipient                | push (if foreground silent) | /chat/:fromUserId    |
| `SUPPORT_TICKET_UPDATE`              | user                     | push + inapp                | /support/ticket/:id  |
| `SAFETY_SOS_TRIGGERED`               | emergency contacts (SMS) | sms                         | n/a                  |

---

## 16. Safety & SOS (Sprint 6)

| #       | Use                                                 | Endpoint                    | Method | Auth   |
| ------- | --------------------------------------------------- | --------------------------- | ------ | ------ |
| 16.1 🛟 | Trigger SOS during trip                             | `/trips/:id/sos`            | POST   | bearer |
| 16.2 🛟 | Share trip live with contacts (SMS link, no auth)   | `/trips/:id/share`          | POST   | bearer |
| 16.3 🛟 | Read public share (the recipient — no auth, masked) | `/shared-trips/:token`      | GET    | public |
| 16.4 🛟 | Stop sharing                                        | `/trips/:id/share/:shareId` | DELETE | bearer |
| 16.5 🛟 | Pre-trip safety check-in (optional)                 | `/trips/:id/safety-checkin` | POST   | bearer |

**SOS payload:** server sends SMS to user's emergency contacts with trip ID, driver name, vehicle plate, last known location, and a public share link (Sprint 6).

---

## 17. Support & disputes

| #       | Use                                                     | Endpoint                        | Method | Auth   |
| ------- | ------------------------------------------------------- | ------------------------------- | ------ | ------ |
| 17.1 🔔 | Open support ticket (categories, optional trip context) | `/support/tickets`              | POST   | bearer |
| 17.2 🔔 | My tickets                                              | `/support/tickets/me`           | GET    | bearer |
| 17.3 🔔 | Ticket detail with messages                             | `/support/tickets/:id`          | GET    | bearer |
| 17.4 🔔 | Reply to ticket                                         | `/support/tickets/:id/messages` | POST   | bearer |
| 17.5 🔔 | Report lost item (subtype of ticket)                    | `/support/lost-item`            | POST   | bearer |

**Categories:** `PAYMENT_ISSUE`, `DRIVER_BEHAVIOR`, `RIDER_BEHAVIOR`, `SAFETY`, `LOST_ITEM`, `APP_BUG`, `KYC`, `OTHER`.

---

## 18. Help center / static content

| #       | Use                              | Endpoint                  | Method | Auth   |
| ------- | -------------------------------- | ------------------------- | ------ | ------ |
| 18.1 🛟 | FAQ list (grouped by category)   | `/content/faq`            | GET    | public |
| 18.2 🛟 | Help article by slug             | `/content/articles/:slug` | GET    | public |
| 18.3 🛟 | Tos / Privacy / Driver agreement | `/content/legal/:slug`    | GET    | public |

Stored as Markdown in `content_pages` table, editable in admin.

---

## 19. Ratings & reviews aggregates

| #       | Use                                         | Endpoint                     | Method | Auth   |
| ------- | ------------------------------------------- | ---------------------------- | ------ | ------ |
| 19.1 ⏳ | Driver public summary (rating, total trips) | `/drivers/:publicId/summary` | GET    | bearer |
| 19.2 ⏳ | Rider public summary (rating)               | `/users/:publicId/summary`   | GET    | bearer |

(Detailed reviews list is admin-only for safety.)

---

## 20. App config & version checks (mobile bootstrap)

| #       | Use                                                                                                                                  | Endpoint               | Method | Auth   |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- | ------ | ------ |
| 20.1 🔧 | App config (vehicle types, support phone, terms URL, force-update)                                                                   | `/app/config`          | GET    | public |
| 20.2 🔧 | Version check headers — backend reads `X-App-Version`, `X-App-Platform`, `X-Device-Id` on every request; returns 426 if force-update | (header on every call) | n/a    | n/a    |

**App config response:**

```json
{
  "vehicleTypes": [{ "code": "BIKE", "label": "Bike", "iconUrl": "..." }, ...],
  "supportPhone": "+919999999999",
  "supportEmail": "support@example.com",
  "termsUrl": "...",
  "privacyUrl": "...",
  "driverAgreementUrl": "...",
  "city": "Kolkata",
  "currency": "INR",
  "languages": ["en", "bn", "hi"],
  "razorpayKeyId": "rzp_test_xxx",
  "minSupportedVersion": { "android": "1.0.0", "ios": "1.0.0" },
  "latestVersion": { "android": "1.0.0", "ios": "1.0.0" },
  "forceUpdate": false,
  "supportHours": "9am – 9pm IST"
}
```

App pulls this on launch and after every login. Cache for 6h.

---

## 21. WebSocket event catalog (single reference)

| Event                       | Direction                  | Namespace / Room          | Payload                                                                    |
| --------------------------- | -------------------------- | ------------------------- | -------------------------------------------------------------------------- |
| `trip.offered`              | server → driver            | `/driver`                 | `{ offerId, tripPreview, expiresAt }`                                      |
| `trip.matched`              | server → rider             | `/rider`                  | `{ tripId, driver, vehicle, etaSec }`                                      |
| `trip.status.changed`       | server → both              | room `trip:{id}`          | `{ tripId, status, at }`                                                   |
| `trip.driver.arrived`       | server → rider             | room `trip:{id}`          | `{ tripId, at }`                                                           |
| `driver.location.updated`   | server → rider             | room `trip:{id}`          | `{ tripId, location, recordedAt, speed?, bearing? }`                       |
| `trip.completed`            | server → both              | room `trip:{id}`          | `{ tripId, summary }`                                                      |
| `trip.cancelled`            | server → both              | room `trip:{id}`          | `{ tripId, by, reason, at }`                                               |
| `chat.message.received`     | server → recipient         | `/rider` or `/driver`     | `{ messageId, fromUserId, text, sentAt, scheduledTripId? }`                |
| `chat.typing`               | both ways                  | room `chat:{otherUserId}` | `{ fromUserId, typing: true/false }`                                       |
| `notification.received`     | server → user              | `/rider` or `/driver`     | `{ id, type, title, body, data }`                                          |
| `trip:join`                 | client → server            | n/a                       | `{ tripId }` — client requests room join                                   |
| `trip:leave`                | client → server            | n/a                       | `{ tripId }`                                                               |
| `driver.location.broadcast` | driver → server (optional) | n/a                       | `{ lat, lng, speed?, bearing? }` — alternative to REST ping for live trips |

---

## 22. Error code catalog (mobile-relevant)

These are the codes Flutter must handle gracefully:

| Code                                    | HTTP | When                                           | Mobile behavior                         |
| --------------------------------------- | ---- | ---------------------------------------------- | --------------------------------------- |
| `VALIDATION_ERROR`                      | 400  | Bad payload                                    | Show field error                        |
| `UNAUTHENTICATED`                       | 401  | Missing token                                  | Kick to login                           |
| `TOKEN_EXPIRED`                         | 401  | Access token expired                           | Auto-refresh + retry                    |
| `FORBIDDEN`                             | 403  | Role wrong                                     | Show "not allowed" toast                |
| `NOT_FOUND`                             | 404  | Resource gone                                  | Toast + back                            |
| `DUPLICATE`                             | 409  | E.g., phone already exists                     | Field error                             |
| `INVALID_STATE`                         | 422  | Trip can't be cancelled in state               | Toast                                   |
| `RATE_LIMITED`                          | 429  | Too many attempts                              | Show retry-after                        |
| `INTERNAL_ERROR`                        | 500  | Server bug                                     | "Try again"                             |
| `SERVICE_UNAVAILABLE`                   | 503  | DB / payment gateway down                      | "Try again later"                       |
| `FORCE_UPDATE_REQUIRED`                 | 426  | App version too old                            | Force update screen                     |
| `OTP_INVALID`                           | 400  | Wrong OTP                                      | Field error                             |
| `OTP_EXPIRED`                           | 400  | OTP > 5 min                                    | "Resend OTP"                            |
| `OTP_TOO_MANY`                          | 429  | Too many sends                                 | "Try again in 10 min"                   |
| `PHONE_ALREADY_REGISTERED`              | 409  | Signup with existing phone                     | Switch to login screen                  |
| `INVALID_CREDENTIALS`                   | 401  | Wrong phone/password                           | Generic error (don't reveal which)      |
| `PASSWORD_NOT_SET`                      | 400  | User signed up OTP-only                        | Prompt to use OTP login or set password |
| `ACCOUNT_SUSPENDED`                     | 403  | Suspended user tries action                    | Show suspension reason                  |
| `ACCOUNT_BANNED`                        | 403  | Banned                                         | Show ban screen                         |
| `ACCOUNT_DELETION_PENDING`              | 403  | Account pending deletion                       | Offer cancel-deletion flow              |
| `KYC_INCOMPLETE`                        | 403  | Driver tries go online                         | Route to KYC screen                     |
| `KYC_REJECTED`                          | 403  | KYC failed                                     | Show rejection reason + re-upload       |
| `VEHICLE_NOT_APPROVED`                  | 403  | Going online with unapproved vehicle           | Show pending                            |
| `DRIVER_NOT_AVAILABLE`                  | 422  | No drivers within radius                       | "No drivers nearby"                     |
| `DRIVER_OFFLINE`                        | 422  | Driver went offline mid-flow                   | Retry match                             |
| `TRIP_ALREADY_ACCEPTED`                 | 409  | Two drivers race-condition                     | Server already routed; client refresh   |
| `TRIP_NOT_CANCELABLE`                   | 422  | Trip past cancellation point                   | Toast                                   |
| `INSUFFICIENT_SEATS`                    | 409  | Carpool full                                   | Show "fully booked"                     |
| `TRIP_FULL`                             | 409  | Scheduled trip full                            | Show "fully booked"                     |
| `PAYMENT_FAILED`                        | 422  | Razorpay declined                              | Retry / change method                   |
| `PAYMENT_REQUIRED`                      | 402  | Trying to access locked feature without paying | Show payment screen                     |
| `IDEMPOTENCY_KEY_REUSED_DIFFERENT_BODY` | 409  | Same key, different payload                    | Bug in client                           |

---

## 23. Mobile-only design rules (backend will enforce these)

1. **Background location pings**: max 1 per 2s per driver. Excess → 429.
2. **Trip OTP**: 4 digits, displayed to rider only. Driver must enter it to start trip.
3. **Share-trip link**: 24h TTL, public read, shows masked driver name + vehicle plate (last 4) + live location until trip ends.
4. **Account deletion**: 30-day soft delete. User can cancel within that window via `delete-request/cancel`. After 30d → hard delete (cron job, Sprint 10).
5. **Force update**: app reads `latestVersion` from `/app/config`; if client version < `minSupportedVersion`, app must block UI and show update screen.
6. **App version header**: every request must send `X-App-Version: <semver>`, `X-App-Platform: ios|android`, `X-Device-Id: <uuid>`. Backend logs to Sentry breadcrumb.
7. **Rate limits per endpoint**: see [API_CONVENTIONS.md](API_CONVENTIONS.md).
8. **No PII in push payloads**: titles/bodies must be generic enough to safely appear on lock screens.

---

## 24. Mobile build order (recommended)

Two parallel Flutter devs:

### Track A — Rider app

1. Splash + token check (✅)
2. Signup + login flow (🔧 Sprint 5)
3. Home with map + saved places (✅)
4. Address autocomplete + route + fare (✅)
5. Request ride + status (✅)
6. Trip tracking via WS (⏳ Sprint 7 — mock until then)
7. Payment flow (💰 Sprint 8 — mock until then)
8. Ratings + history (⏳ Sprint 7)
9. Carpool search + book (🚗 Sprint 9)
10. Chat (🚗 Sprint 9)
11. Notifications inbox (🔔 Sprint 10)
12. Support (🔔 Sprint 10)
13. Safety / SOS (🛟 Sprint 6)

### Track B — Driver app (same binary, role switch)

1. KYC upload (✅)
2. Vehicle add (✅)
3. Driver home + online toggle (✅)
4. Trip offer flow (✅ Sprint 4 + ⏳ Sprint 7)
5. Trip lifecycle (⏳ Sprint 7)
6. Earnings + payout (💰 Sprint 8)
7. Post carpool trip (🚗 Sprint 9)
8. Driver chat (🚗 Sprint 9)

### Sprint-by-sprint mobile coverage matrix

| Sprint        | Mobile features unlocked                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------- |
| ✅ 1–4 (done) | Profile, KYC, vehicle, addresses, maps, fare, online/offline, ride request, matching, WS skeleton |
| 🔧 5          | Phone+password login, full signup, forgot password, role upgrade, app config                      |
| 🛟 6          | SOS, share trip, account delete, language prefs, FAQ                                              |
| ⏳ 7          | Trip arrive/start/end, ratings, live tracking, history                                            |
| 💰 8          | Razorpay UPI, wallet, payouts, invoices, saved payment methods                                    |
| 🚗 9          | Carpool post/search/book/cancel, chat                                                             |
| 🔔 10         | FCM push, in-app notifications, support tickets, lost item                                        |

After **Sprint 6 + 7**, both rider and driver apps can be tested end-to-end (without payments). After **Sprint 8**, full money flow works. After **10**, ready for beta launch.

---

## 25. What backend will NOT provide (Flutter handles client-side)

- Localization strings (Flutter uses `.arb` files; backend returns canonical English)
- Image compression before upload (client must resize to ≤1024px wide, JPEG quality 80)
- Offline queue for location pings (client buffers, sends on reconnect, capped at 100 pings)
- Map tiles (Flutter fetches from OSM directly)
- Razorpay UI (Flutter uses `razorpay_flutter` plugin)
- Biometric login (client-only — refresh token sits behind device biometric prompt)
- Native phone dialer for emergency call (use `url_launcher` with `tel:` scheme)

---

## 26. Postman / mock server

- **Postman workspace** — shared via Slack
- **Mock server** during dev: `prism mock <swagger-url>` (see [FLUTTER_HANDOFF.md](FLUTTER_HANDOFF.md))
- Per-sprint collection added under `docs/postman/`

---

## 27. Open questions to confirm with founder

These are product decisions that change the API surface — get answers before Sprint 7:

1. **Cancellation policy values?** (Currently placeholder: free <2min after accept, ₹30 after.)
2. **Driver commission %?** (Currently placeholder: 10% + 5% GST.)
3. **Carpool cancellation refunds?** (Currently: 100% if >24h before, 50% if 12-24h, 0% if <12h.)
4. **Minimum age for driver?** (Required for date_of_birth validation.)
5. **Should rider see driver's full name or just first name + photo?** (Privacy tradeoff.)
6. **Real-time vs batched FCM for trip status?** (We assume real-time WS + push for critical events.)
7. **Multiple bookings per trip allowed?** (Yes assumed; one trip can have 3 passengers from 3 different bookings.)
8. **In-app calling vs phone deep-link?** (Phone deep-link for MVP; in-app calling = ₹0.50/min via Exotel/Twilio = paid.)
