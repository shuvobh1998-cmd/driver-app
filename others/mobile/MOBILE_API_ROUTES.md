# Mobile API — Route Reference (M01–M08)

> One-page reference for the Flutter team. Every **mobile** route (rider + driver)
> the backend exposes, with auth, params, and a one-line purpose. Admin-panel
> routes (`/admin/**`) are intentionally excluded — the app never calls them.
>
> Generated from the live controllers. For request/response field detail, the
> **Swagger UI at `/docs`** is the source of truth (always in sync with the code).

---

## Conventions (read first)

- **Base URL:** every path below is prefixed with `/api/v1`. e.g. `GET /auth/me` → `GET https://<host>/api/v1/auth/me`.
- **Auth:** send `Authorization: Bearer <accessToken>` on every route except those marked **Public**. Access token TTL ≈ 15 min — on `401 TOKEN_EXPIRED`, call `POST /auth/refresh` then retry.
- **Roles:** `R` = rider token, `D` = driver token, `Any` = any signed-in user, `Public` = no token. (A user who upgraded to driver carries both roles.)
- **Response envelope:** success → `{ "success": true, "data": <payload>, "meta": {...} }`. Paginated → `{ "success": true, "data": [...], "pagination": { page, pageSize, total, hasMore }, "meta": {...} }`. Error → `{ "success": false, "error": { code, message, field }, "meta": {...} }`.
- **Pagination:** list endpoints accept `?page=1&pageSize=20` (query).
- **IDs:** prefixed public ids only — `usr_`, `drv`/driver=usr, `veh_`, `trp_`, `req_`, `off_`, `sch_`, `bkg_`, `pay_`, `pyt_`, `pmt_`, `led_`, `ntf_`, `shr_`, `sos_`, `tkt_`, `tms_`, `ses_`, `msg_`. Never numeric.
- **Money:** integer **paise** (₹125.50 → `12550`). **Location:** `{ "lat": number, "lng": number }`. **Time:** ISO-8601 UTC.
- **Idempotency:** routes marked **⊕ Idempotency-Key** require a header `Idempotency-Key: <uuid>` (money/state-changing POSTs). Re-sending the same key returns the original response; a different body with the same key → `409`.

---

## 1. App bootstrap & health

| Method | Path          | Auth   | Params | Purpose                                                                                                                             |
| ------ | ------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| GET    | `/health`     | Public | —      | Liveness + DB/Redis check.                                                                                                          |
| GET    | `/app/config` | Public | —      | Vehicle types, support contacts, legal URLs, city, currency, Razorpay key id, min/latest app version, force-update flag. Cache ~6h. |

---

## 2. Auth (M01)

| Method | Path                            | Auth   | Params (body)                             | Purpose                                            |
| ------ | ------------------------------- | ------ | ----------------------------------------- | -------------------------------------------------- |
| POST   | `/auth/otp/send`                | Public | `phone`                                   | Send login OTP (Firebase).                         |
| POST   | `/auth/otp/verify`              | Public | `idToken`, `deviceInfo?`                  | Verify Firebase OTP → JWT pair (existing user).    |
| POST   | `/auth/signup/start`            | Public | `phone`                                   | Begin signup; sends OTP.                           |
| POST   | `/auth/signup/verify-otp`       | Public | `idToken`                                 | Verify signup OTP → short-lived signup token.      |
| POST   | `/auth/signup/complete`         | Public | `signupToken`, `firstName`, `lastName`, … | Create the account → JWT pair.                     |
| POST   | `/auth/login`                   | Public | `phone`/`email`, `password`               | Password login → JWT pair.                         |
| POST   | `/auth/password/forgot/request` | Public | `phone`/`email`                           | Send password-reset OTP.                           |
| POST   | `/auth/password/forgot/reset`   | Public | `idToken`, `newPassword`                  | Reset password, revoke all sessions, new JWT pair. |
| POST   | `/auth/password/change`         | Any    | `currentPassword`, `newPassword`          | Change password, revoke sessions, new pair.        |
| POST   | `/auth/password/set`            | Any    | `newPassword`                             | Set a password for an OTP-only account.            |
| POST   | `/auth/refresh`                 | Public | `refreshToken`                            | Rotate refresh token → new JWT pair.               |
| POST   | `/auth/logout`                  | Any    | `refreshToken`                            | Revoke one refresh token (this device).            |
| POST   | `/auth/logout/all-others`       | Any    | `refreshToken` (the one to keep)          | Revoke every other session. → `{ revoked }`        |
| GET    | `/auth/me`                      | Any    | —                                         | Current authenticated user.                        |

---

## 3. Profile, addresses & settings (M01 · M08)

| Method | Path                                      | Auth | Params                                                   | Purpose                                      |
| ------ | ----------------------------------------- | ---- | -------------------------------------------------------- | -------------------------------------------- |
| GET    | `/users/me/profile`                       | Any  | —                                                        | Current user profile.                        |
| PATCH  | `/users/me/profile`                       | Any  | `firstName?`, `lastName?`, `email?`, `dob?`, `gender?`   | Update profile.                              |
| POST   | `/users/me/avatar`                        | Any  | multipart `file`                                         | Upload avatar.                               |
| POST   | `/users/me/upgrade-to-driver`             | R    | —                                                        | Add the DRIVER role + create driver profile. |
| GET    | `/users/me/recent-locations`              | Any  | `?limit`                                                 | Deduped recent pickup/drop points.           |
| GET    | `/users/me/addresses`                     | Any  | —                                                        | Saved addresses (home/work/…).               |
| POST   | `/users/me/addresses`                     | Any  | `label`, `addressText`, `location{lat,lng}`              | Save an address.                             |
| PATCH  | `/users/me/addresses/:id`                 | Any  | `label?`, `addressText?`, `location?`                    | Update a saved address.                      |
| DELETE | `/users/me/addresses/:id`                 | Any  | —                                                        | Remove a saved address.                      |
| GET    | `/users/me/preferences`                   | Any  | —                                                        | `{ language, marketingPush, marketingSms }`. |
| PATCH  | `/users/me/preferences`                   | Any  | `language?`(en/bn/hi), `marketingPush?`, `marketingSms?` | Update preferences.                          |
| POST   | `/users/me/account/delete-request`        | Any  | —                                                        | Schedule deletion (30-day reversible grace). |
| POST   | `/users/me/account/delete-request/cancel` | Any  | —                                                        | Cancel a pending deletion.                   |
| GET    | `/users/me/sessions`                      | Any  | —                                                        | Active sessions (device, current flag).      |
| DELETE | `/users/me/sessions/:id`                  | Any  | `:id` = `ses_*`                                          | Revoke one session.                          |

---

## 4. Driver onboarding, KYC & vehicles (M03)

| Method | Path                             | Auth | Params                                              | Purpose                              |
| ------ | -------------------------------- | ---- | --------------------------------------------------- | ------------------------------------ |
| POST   | `/drivers/me/profile`            | D    | profile fields                                      | Create driver profile.               |
| GET    | `/drivers/me/profile`            | D    | —                                                   | Driver profile.                      |
| PATCH  | `/drivers/me/profile`            | D    | `emergencyContactName?`, `emergencyContactPhone?`   | Update emergency contact.            |
| POST   | `/drivers/me/kyc/documents`      | D    | multipart `file`, `docType`, `docNumber?`           | Upload/replace a KYC doc.            |
| GET    | `/drivers/me/kyc/documents`      | D    | —                                                   | List my KYC docs.                    |
| DELETE | `/drivers/me/kyc/documents/:id`  | D    | —                                                   | Delete a KYC doc.                    |
| GET    | `/drivers/me/kyc/status`         | D    | —                                                   | Overall KYC status + missing docs.   |
| POST   | `/drivers/me/vehicles`           | D    | `vehicleType`, `registrationNumber`, `seatCount`, … | Register a vehicle.                  |
| GET    | `/drivers/me/vehicles`           | D    | —                                                   | My vehicles (excludes soft-deleted). |
| PATCH  | `/drivers/me/vehicles/:id`       | D    | `:id` = `veh_*`; editable fields                    | Update a vehicle.                    |
| DELETE | `/drivers/me/vehicles/:id`       | D    | `:id` = `veh_*`                                     | Soft-delete a vehicle.               |
| POST   | `/drivers/me/vehicles/:id/photo` | D    | multipart `file`                                    | Upload vehicle photo.                |

---

## 5. Maps & fares (M02)

| Method | Path                    | Auth | Params                                    | Purpose                                         |
| ------ | ----------------------- | ---- | ----------------------------------------- | ----------------------------------------------- |
| GET    | `/maps/geocode`         | Any  | `?q`                                      | Address → coordinates.                          |
| GET    | `/maps/reverse-geocode` | Any  | `?lat&lng`                                | Coordinates → address.                          |
| POST   | `/maps/route`           | Any  | `origin{lat,lng}`, `destination{lat,lng}` | Route geometry + distance/duration.             |
| POST   | `/fares/estimate`       | Any  | `origin`, `destination`, `vehicleType`    | Fare estimate for one vehicle type.             |
| POST   | `/fares/estimate-all`   | Any  | `origin`, `destination`                   | Fare for all vehicle types (Bike/Auto/CNG/Car). |

---

## 6. On-demand ride — rider (M04)

| Method | Path                         | Auth | Params                                                                                                       | Purpose                                                              |
| ------ | ---------------------------- | ---- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| POST   | `/rides/request`             | R    | `pickupLocation`, `pickupAddress?`, `dropLocation`, `dropAddress?`, `vehicleType`, `paymentMethod`, `notes?` | Create a ride request; async matching starts.                        |
| GET    | `/rides/requests/:id`        | R    | `:id` = `req_*`                                                                                              | Request status; once matched → `matchedTrip` (driver, vehicle, ETA). |
| POST   | `/rides/requests/:id/cancel` | R    | `reason?`                                                                                                    | Cancel a pending request.                                            |

## 6b. On-demand ride — driver (M04 · M05)

| Method | Path                                       | Auth | Params                             | Purpose                                             |
| ------ | ------------------------------------------ | ---- | ---------------------------------- | --------------------------------------------------- |
| POST   | `/drivers/me/online`                       | D    | `vehicleId`                        | Go online (gated on KYC APPROVED + vehicle ACTIVE). |
| POST   | `/drivers/me/offline`                      | D    | —                                  | Go offline.                                         |
| POST   | `/drivers/me/location`                     | D    | `lat`, `lng`, `bearing?`, `speed?` | Location ping (~every 5s while online).             |
| GET    | `/drivers/me/state`                        | D    | —                                  | Current driver state.                               |
| POST   | `/drivers/me/trip-offers/:offerId/accept`  | D    | `:offerId` = `off_*`               | Accept a trip offer → creates the trip.             |
| POST   | `/drivers/me/trip-offers/:offerId/decline` | D    | —                                  | Decline a trip offer.                               |

---

## 7. Trip lifecycle, ratings & history (M05)

| Method | Path                        | Auth                     | Params                          | Purpose                                                    |
| ------ | --------------------------- | ------------------------ | ------------------------------- | ---------------------------------------------------------- |
| GET    | `/trips/me`                 | R                        | `?page&pageSize`                | Rider trip history.                                        |
| GET    | `/trips/me/current`         | R                        | —                               | Rider's active trip (`404 NO_ACTIVE_TRIP` if none).        |
| GET    | `/drivers/me/trips`         | D                        | `?page&pageSize`                | Driver trip history.                                       |
| GET    | `/drivers/me/trips/current` | D                        | —                               | Driver's active trip (`404 NO_ACTIVE_TRIP`).               |
| GET    | `/trips/:id`                | Any (rider/driver/admin) | `:id` = `trp_*`                 | Trip detail.                                               |
| POST   | `/trips/:id/arrived`        | D                        | —                               | ACCEPTED → ARRIVED.                                        |
| POST   | `/trips/:id/start`          | D                        | `otp` (4-digit, shown to rider) | ARRIVED → STARTED. `400 OTP_REQUIRED` / `409 OTP_INVALID`. |
| POST   | `/trips/:id/end`            | D                        | —                               | STARTED → ENDED; finalizes fare.                           |
| POST   | `/trips/:id/cancel`         | Any                      | `reason?`                       | Cancel before STARTED (ACCEPTED/ARRIVED).                  |
| POST   | `/trips/:id/rate-driver`    | R                        | `rating`(1–5), `comment?`       | Rate driver after ENDED.                                   |
| POST   | `/trips/:id/rate-rider`     | D                        | `rating`(1–5), `comment?`       | Rate rider after ENDED.                                    |
| POST   | `/trips/:id/report`         | Any                      | `category`, `description`       | Report a problem with a trip.                              |

---

## 8. Payments — rider (M06)

| Method | Path                                        | Auth           | Params                                                   | Purpose                                                                                             |
| ------ | ------------------------------------------- | -------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| POST   | `/trips/:id/payment/order`                  | R              | —                                                        | Create a Razorpay order for a finished UPI/CARD trip → `{ gatewayOrderId, amount, razorpayKeyId }`. |
| POST   | `/trips/:id/payment/verify` ⊕               | R              | `razorpayPaymentId`, `razorpaySignature`                 | Verify signature → settle; credits driver wallet. `422 PAYMENT_FAILED` if invalid.                  |
| GET    | `/trips/:id/invoice`                        | Any (involved) | —                                                        | Invoice JSON (line items, total).                                                                   |
| GET    | `/trips/:id/invoice.pdf`                    | Any (involved) | —                                                        | Invoice PDF (binary, `application/pdf`).                                                            |
| GET    | `/users/me/payment-methods`                 | R              | —                                                        | Saved methods (default first).                                                                      |
| POST   | `/users/me/payment-methods`                 | R              | `type`(UPI/CARD), `label`, `gatewayToken?`, `isDefault?` | Save a payment method.                                                                              |
| DELETE | `/users/me/payment-methods/:id`             | R              | `:id` = `pmt_*`                                          | Delete a method (promotes next to default).                                                         |
| POST   | `/users/me/payment-methods/:id/set-default` | R              | `:id` = `pmt_*`                                          | Set default.                                                                                        |

## 8b. Payments — driver: cash, wallet, payouts, earnings (M06)

| Method | Path                                  | Auth | Params                                                               | Purpose                                                           |
| ------ | ------------------------------------- | ---- | -------------------------------------------------------------------- | ----------------------------------------------------------------- |
| POST   | `/trips/:id/payment/cash-collected` ⊕ | D    | — (no body)                                                          | Close a CASH trip; debits commission+GST from wallet.             |
| GET    | `/drivers/me/wallet`                  | D    | —                                                                    | Balance + lifetime totals.                                        |
| GET    | `/drivers/me/wallet/ledger`           | D    | `?page&pageSize`                                                     | Ledger entries (CREDIT/DEBIT, reason, balanceAfter).              |
| GET    | `/drivers/me/earnings/today`          | D    | —                                                                    | Today's gross + net (IST).                                        |
| GET    | `/drivers/me/earnings/this-week`      | D    | —                                                                    | This week (from Monday, IST).                                     |
| GET    | `/drivers/me/earnings/this-month`     | D    | —                                                                    | This month (IST).                                                 |
| GET    | `/drivers/me/payout-method`           | D    | —                                                                    | Payout method (account number masked).                            |
| PUT    | `/drivers/me/payout-method`           | D    | `methodType`(UPI/BANK), `upiId?` / `accountName,accountNumber,ifsc?` | Set payout method.                                                |
| POST   | `/drivers/me/payouts/request` ⊕       | D    | `amount`(paise), `notes?`                                            | Request a withdrawal (debits wallet). `422 INSUFFICIENT_BALANCE`. |
| GET    | `/drivers/me/payouts`                 | D    | `?page&pageSize`                                                     | My payouts.                                                       |
| GET    | `/drivers/me/payouts/:id`             | D    | `:id` = `pyt_*`                                                      | Payout detail.                                                    |

---

## 9. Scheduled carpool ("firti gari") (M07)

### Driver

| Method | Path                            | Auth | Params                                                                                                                                                    | Purpose                                               |
| ------ | ------------------------------- | ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| POST   | `/scheduled-trips`              | D    | `origin`, `originAddress?`, `destination`, `destAddress?`, `departureAt`, `vehicleId`, `totalSeats`, `pricePerSeat`, `notes?`, `preferences{ac?,gender?}` | Post a planned trip.                                  |
| GET    | `/scheduled-trips/me`           | D    | `?status&page&pageSize`                                                                                                                                   | My posted trips.                                      |
| PATCH  | `/scheduled-trips/:id`          | D    | any of the create fields                                                                                                                                  | Edit (only while OPEN with no bookings).              |
| POST   | `/scheduled-trips/:id/cancel`   | D    | `reason?`                                                                                                                                                 | Cancel → refunds all bookings 100% + notifies riders. |
| GET    | `/scheduled-trips/:id/bookings` | D    | —                                                                                                                                                         | Bookings on my trip (with rider info).                |
| POST   | `/scheduled-trips/:id/start`    | D    | —                                                                                                                                                         | Start trip day (→ IN_PROGRESS).                       |
| POST   | `/scheduled-trips/:id/complete` | D    | —                                                                                                                                                         | Complete the trip.                                    |
| POST   | `/bookings/:id/no-show`         | D    | `:id` = `bkg_*`                                                                                                                                           | Mark a booking no-show (while IN_PROGRESS).           |

### Rider

| Method | Path                                 | Auth               | Params                                                                                                                     | Purpose                                                         |
| ------ | ------------------------------------ | ------------------ | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| GET    | `/scheduled-trips/search`            | R                  | `pickupLat,pickupLng,dropLat,dropLng`, `date?`, `timeWindowHours?`, `seats?`, `vehicleType?`, `priceMax?`, `radiusMeters?` | Route search (both ends within radius, OPEN, seats free).       |
| GET    | `/scheduled-trips/:id`               | Any                | `:id` = `sch_*`                                                                                                            | Trip detail (driver, vehicle, seats, price, prefs).             |
| POST   | `/scheduled-trips/:id/bookings`      | R                  | `seats`, `pickup{lat,lng}?`, `pickupAddress?`, `dropAddress?`                                                              | Book seats. `422 TRIP_FULL`, `409 DUPLICATE` if already booked. |
| GET    | `/bookings/me`                       | R                  | `?filter=upcoming\|past&page&pageSize`                                                                                     | My bookings.                                                    |
| GET    | `/bookings/:id`                      | Any (rider/driver) | `:id` = `bkg_*`                                                                                                            | Booking detail.                                                 |
| GET    | `/bookings/:id/cancellation-preview` | R                  | —                                                                                                                          | Refund preview (100% >24h, 50% 12–24h, 0% <12h).                |
| POST   | `/bookings/:id/cancel`               | R                  | `reason?`                                                                                                                  | Cancel; refund per policy + frees the seat.                     |

---

## 10. Chat (M07)

| Method | Path                                   | Auth | Params                                                    | Purpose                                                       |
| ------ | -------------------------------------- | ---- | --------------------------------------------------------- | ------------------------------------------------------------- |
| POST   | `/chats/messages`                      | Any  | `toUserId`(usr*\*), `scheduledTripId?`(sch*\*), `message` | Send a 1:1 message.                                           |
| GET    | `/chats/threads`                       | Any  | `?page&pageSize`                                          | Threads list (last message + unread count).                   |
| GET    | `/chats/threads/:otherUserId/messages` | Any  | `:otherUserId`=usr\_\*; `?page&pageSize`                  | Messages in a thread (newest first; `mine` flag per message). |
| POST   | `/chats/threads/:otherUserId/read`     | Any  | —                                                         | Mark all messages from that user read.                        |

---

## 11. Notifications (M08)

| Method | Path                          | Auth | Params                                                 | Purpose                                                   |
| ------ | ----------------------------- | ---- | ------------------------------------------------------ | --------------------------------------------------------- |
| POST   | `/users/me/device-tokens`     | Any  | `fcmToken`, `platform`(ANDROID/IOS/WEB), `deviceInfo?` | Register/refresh FCM token (call on launch).              |
| DELETE | `/users/me/device-tokens`     | Any  | `fcmToken`                                             | Unregister on sign-out.                                   |
| GET    | `/notifications`              | Any  | `?page&pageSize`                                       | Inbox (newest first; `read`, `type`, `deepLink`, `data`). |
| GET    | `/notifications/unread-count` | Any  | —                                                      | `{ count }` for the tab badge.                            |
| POST   | `/notifications/:id/read`     | Any  | `:id` = `ntf_*`                                        | Mark one read.                                            |
| POST   | `/notifications/read-all`     | Any  | —                                                      | Mark all read → `{ updated }`.                            |

---

## 12. Safety — SOS & live share (M08)

| Method | Path                        | Auth                   | Params                                  | Purpose                                                                                                 |
| ------ | --------------------------- | ---------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| POST   | `/trips/:id/sos`            | Any (trip participant) | `lat?`, `lng?`, `note?`                 | Raise SOS → SMS to emergency contacts + alert counterparty.                                             |
| POST   | `/trips/:id/share`          | Any (participant)      | `recipientPhones?[]`, `expiresInHours?` | Create a live-tracking link + SMS it → `{ url }`.                                                       |
| GET    | `/trips/:id/shares`         | Any (participant)      | —                                       | Active share links for this trip.                                                                       |
| DELETE | `/trips/:id/share/:shareId` | Any (participant)      | `:shareId` = `shr_*`                    | Revoke a link.                                                                                          |
| GET    | `/shared-trips/:token`      | **Public**             | `:token`                                | Masked live view (driver first name + masked plate + status + last location). `404` if revoked/expired. |

---

## 13. Support & content (M08)

| Method | Path                            | Auth        | Params                                          | Purpose                                   |
| ------ | ------------------------------- | ----------- | ----------------------------------------------- | ----------------------------------------- |
| POST   | `/support/tickets`              | Any         | `category`, `subject`, `description`, `tripId?` | Open a ticket.                            |
| POST   | `/support/lost-item`            | Any         | `subject`, `description`, `tripId?`             | Lost-item report (LOST_ITEM ticket).      |
| GET    | `/support/tickets/me`           | Any         | `?status&page&pageSize`                         | My tickets.                               |
| GET    | `/support/tickets/:id`          | Any (owner) | `:id` = `tkt_*`                                 | Ticket detail + message thread.           |
| POST   | `/support/tickets/:id/messages` | Any (owner) | `body`                                          | Post a reply (reopens a RESOLVED ticket). |
| GET    | `/content/faq`                  | **Public**  | `?locale=en\|bn\|hi`                            | FAQ entries (falls back to `en`).         |
| GET    | `/content/articles/:slug`       | **Public**  | `:slug`; `?locale`                              | Help article.                             |
| GET    | `/content/legal/:slug`          | **Public**  | `:slug` (e.g. `terms`, `privacy`); `?locale`    | Legal document.                           |

---

## 14. WebSocket events

Connect: `wss://<host>/ws?token=<accessToken>` (Socket.IO; namespaces `/rider`, `/driver`, `/admin`). On connect you auto-join your private user room.

**Subscribe (server → client):**

| Event                                  | When                                 | Payload (key fields)                                                     |
| -------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| `trip.offered`                         | a request is offered to you (driver) | `{ offerId, rideRequest, pickupAddress, dropAddress, notes, expiresAt }` |
| `trip.matched`                         | your request matched (rider)         | `{ tripId, driver, vehicle, etaToPickupSec }`                            |
| `trip.status.changed`                  | trip state transition                | `{ tripId, status, at }`                                                 |
| `trip.driver.arrived`                  | driver reached pickup                | `{ tripId, at }`                                                         |
| `trip.location.updated`                | in-trip driver position (rider map)  | `{ tripId, lat, lng, bearing, at }`                                      |
| `trip.completed`                       | trip ended                           | `{ tripId, summary }`                                                    |
| `trip.cancelled`                       | trip cancelled                       | `{ tripId, by, reason, at }`                                             |
| `payment.succeeded` / `payment.failed` | payment settled / declined           | `{ tripId, amount?, method?, reason? }`                                  |
| `chat.message.received`                | a chat message arrives               | a `MessageDto` (`id, fromUserId, toUserId, body, type, createdAt`)       |
| `notification.received`                | a new in-app notification            | a `NotificationDto` (`id, type, title, body, deepLink, data`)            |

**Publish (client → server):** `trip.subscribe` / `trip.unsubscribe` `{ tripId }` to join a trip room; `trip.location` (driver) to stream in-trip positions.

---

## 15. Common error codes

`VALIDATION_ERROR` (400) · `UNAUTHENTICATED` / `TOKEN_EXPIRED` (401) · `FORBIDDEN` (403) · `NOT_FOUND` (404) · `DUPLICATE` (409) · `INVALID_STATE` (409/422) · `RATE_LIMITED` (429). Domain: `OTP_REQUIRED`/`OTP_INVALID`, `KYC_INCOMPLETE`/`KYC_REJECTED`, `VEHICLE_NOT_APPROVED`, `NO_ACTIVE_TRIP`, `ALREADY_RATED`, `TRIP_FULL`, `PAYMENT_FAILED`, `INSUFFICIENT_BALANCE`, `PAYOUT_METHOD_REQUIRED`, `GENDER_NOT_ALLOWED`, `IDEMPOTENCY_KEY_REUSED_DIFFERENT_BODY`.

> Always branch on `error.code` (stable), not the HTTP status or message text.
