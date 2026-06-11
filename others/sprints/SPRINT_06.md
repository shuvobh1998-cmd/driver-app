# Sprint 6 — Mobile Safety, Privacy & Help Center

> **Duration:** 2 weeks
> **Theme:** SOS, share trip, account deletion, language preferences, FAQ / help articles, recent locations — the mobile-only surface that doesn't fit elsewhere.

## Goal

Close the gap between what mobile devs need to build a real, production-shaped app and what Sprints 1–8 already cover. After this sprint a Flutter dev can wire up: SOS button on trip screen, share-trip-with-family flow, settings page (language + notification prefs), account deletion request, in-app help center.

## Why this sprint

Founder-funded production apps must have these on day 1 — not because of MVP scope, but because:

- **Safety / SOS** — competitive table-stakes in India after Uber/Ola scandals. Riders won't use an app without one.
- **Account deletion** — Google Play and Apple App Store _require_ in-app deletion request. Cannot publish without it.
- **Language preference** — Bengali / Hindi are essential for Kolkata market reach.
- **Help center / FAQ** — reduces support ticket volume by 40%+.
- **Share trip** — top requested feature in every ride app — riders share live location with family.

These features need ~30 lines each on the backend but are massive UX features on the app.

## Features

### 1. Recent locations

- Auto-populated from past trips (top 10 recent unique drop locations)
- `GET /api/v1/users/me/recent-locations` returns `[{label, address, location, lastUsedAt}]`
- No DB table — derive from `trips` + `seat_bookings` with window function. Cache 1h in Redis.

### 2. User preferences

Migration `0013_user_preferences`:

- `user_preferences` table: `user_id PK FK`, `language VARCHAR(5) DEFAULT 'en'`, `marketing_push BOOL DEFAULT TRUE`, `marketing_sms BOOL DEFAULT FALSE`, `marketing_email BOOL DEFAULT TRUE`, `trip_push_sound BOOL DEFAULT TRUE`, `updated_at`

Endpoints:

- `GET /api/v1/users/me/preferences`
- `PATCH /api/v1/users/me/preferences`

Default row created when user is created (in Sprint 5 signup flow — add to that endpoint).

### 3. Account deletion (Play/App Store compliance)

Soft delete with 30-day grace period:

Migration `0014_account_deletion`:

- `users` additions: `deletion_requested_at TIMESTAMPTZ NULL`, `deletion_reason TEXT`
- New table `account_deletion_log` for audit

Endpoints:

- `POST /api/v1/users/me/account/delete-request` — body `{ reason? }`. Sets `deletion_requested_at = now()`, status stays ACTIVE but flagged.
- `POST /api/v1/users/me/account/delete-request/cancel` — clears the flag.
- `POST /api/v1/users/me/account/data-export` — queues a Bull job that writes a JSON dump of user's data to Cloudinary; emails signed link.

Auth changes:

- On login, if `deletion_requested_at` is set and within 30d → return user data + a `accountDeletionPending` flag + days remaining. App shows "cancel deletion" CTA.
- After 30d a cron job hard-deletes the user (Sprint 10).

### 4. SOS button (trip-scoped)

Migration `0015_sos_events`:

- `sos_events` table: `id PK`, `trip_id FK`, `triggered_by_user_id FK`, `location geography(Point, 4326)`, `triggered_at TIMESTAMPTZ`, `notes TEXT`, `resolved_at TIMESTAMPTZ`

Endpoint:

- `POST /api/v1/trips/:id/sos` — body `{ notes? }`
  - Captures current location from most recent `trip_location_pings` row
  - Sends SMS to:
    - User's `emergency_contact_phone` (set in Sprint 5)
    - A platform safety hotline (configured in `app_config`)
  - SMS includes: "[NAME] triggered SOS on trip [trip public id]. Driver: [first name] ([vehicle make/model], plate [...XXXX]). Last location: [Google Maps link]. Trip share: [public link]."
  - Pushes notification to admin "Safety" channel (admin panel will show real-time SOS dashboard in Sprint 10)
  - Returns 200 with `{ sosId, sharedTripUrl }`

Admin counterpart (added to Sprint 10 — only data model lands here):

- New table for SOS tracking; admin can mark resolved.

### 5. Share trip live with contacts

Migration `0016_trip_shares`:

- `trip_shares` table: `id PK`, `public_token VARCHAR(40) UNIQUE`, `trip_id FK`, `created_by_user_id FK`, `expires_at TIMESTAMPTZ`, `revoked_at TIMESTAMPTZ`

Endpoints:

- `POST /api/v1/trips/:id/share` — body `{ recipientPhones: ["+91..."], expiresInHours: 24 }`
  - Creates a `trip_shares` row with random `public_token` (URL-safe)
  - Sends SMS to each recipient: "[Name] is sharing their ride. Track live: [public URL]"
  - Returns `{ shareId, publicUrl }`
- `DELETE /api/v1/trips/:id/share/:shareId` — revoke
- `GET /api/v1/shared-trips/:token` — **public** (no auth)
  - Returns masked: driver first name, vehicle make/model, plate last 4, current location, trip status, ETA, **no** phone numbers, **no** rider info
  - Returns 410 if revoked or expired
  - If trip is `ENDED` or `CANCELLED` for more than 1h → also expired

Mobile: rider taps "Share my ride" → picks contacts from device → sends SMS via this endpoint.

### 6. Help center / FAQ / legal pages (CMS-lite)

Migration `0017_content_pages`:

- `content_pages` table:
  - `id PK`, `slug VARCHAR(80) UNIQUE`, `type VARCHAR(20)` (`FAQ`, `ARTICLE`, `LEGAL`)
  - `title VARCHAR(200)`, `category VARCHAR(50)` (for FAQ grouping)
  - `body_markdown TEXT`, `language VARCHAR(5) DEFAULT 'en'`
  - `published BOOL DEFAULT FALSE`, `display_order INT DEFAULT 0`
  - `created_at`, `updated_at`

Public endpoints (no auth):

- `GET /api/v1/content/faq?lang=en` — list of FAQs grouped by category
- `GET /api/v1/content/articles/:slug?lang=en` — single article
- `GET /api/v1/content/legal/:slug` — Terms / Privacy / Driver agreement etc.

Admin endpoints (Sprint 10 will add UI; just DB + endpoints here):

- `GET /api/v1/admin/content` — list
- `POST /api/v1/admin/content` — create
- `PATCH /api/v1/admin/content/:id` — edit
- `DELETE /api/v1/admin/content/:id` — soft delete

Seed: insert 10 starter FAQs and 3 legal pages (terms, privacy, driver agreement placeholders).

### 7. Logout from all other devices

Endpoint:

- `POST /api/v1/auth/logout/all-others` — revokes every `auth_refresh_tokens` row for current user except current device's token

### 8. Device sessions UI

Endpoints (data is in `auth_refresh_tokens.device_info` from Sprint 1):

- `GET /api/v1/users/me/sessions` — list active sessions: `[{id, deviceInfo, lastSeenAt, current: bool}]`
- `DELETE /api/v1/users/me/sessions/:id` — revoke a session

### 9. App version enforcement middleware

- Read `X-App-Version`, `X-App-Platform` headers on every request
- Compare against `app_config.minSupportedVersion`
- If below → return 426 with `FORCE_UPDATE_REQUIRED`
- Logs to Sentry breadcrumb

## API endpoints delivered

| Method | Path                                      | Auth   | Purpose                   |
| ------ | ----------------------------------------- | ------ | ------------------------- |
| GET    | `/users/me/recent-locations`              | bearer | Top recent drop locations |
| GET    | `/users/me/preferences`                   | bearer | Read prefs                |
| PATCH  | `/users/me/preferences`                   | bearer | Update prefs              |
| POST   | `/users/me/account/delete-request`        | bearer | Request deletion          |
| POST   | `/users/me/account/delete-request/cancel` | bearer | Cancel within 30d         |
| POST   | `/users/me/account/data-export`           | bearer | Queue export              |
| POST   | `/trips/:id/sos`                          | bearer | SOS during trip           |
| POST   | `/trips/:id/share`                        | bearer | Share trip with contacts  |
| DELETE | `/trips/:id/share/:shareId`               | bearer | Revoke share              |
| GET    | `/shared-trips/:token`                    | public | Masked live tracker       |
| GET    | `/content/faq`                            | public | FAQ list                  |
| GET    | `/content/articles/:slug`                 | public | Article                   |
| GET    | `/content/legal/:slug`                    | public | Legal page                |
| GET    | `/admin/content`                          | admin  | Manage CMS                |
| POST   | `/admin/content`                          | admin  | Create                    |
| PATCH  | `/admin/content/:id`                      | admin  | Edit                      |
| DELETE | `/admin/content/:id`                      | admin  | Delete                    |
| POST   | `/auth/logout/all-others`                 | bearer | Revoke other sessions     |
| GET    | `/users/me/sessions`                      | bearer | Active sessions           |
| DELETE | `/users/me/sessions/:id`                  | bearer | Revoke session            |

## DB migrations

1. `0013_user_preferences`
2. `0014_account_deletion` (users additions + audit log)
3. `0015_sos_events`
4. `0016_trip_shares`
5. `0017_content_pages`

## Admin panel pages

| Page                     | Purpose                                             |
| ------------------------ | --------------------------------------------------- |
| `/content`               | List FAQ/articles/legal                             |
| `/content/edit/:id`      | Markdown editor                                     |
| `/users/[id]` (enhanced) | Show deletion status, language pref                 |
| `/safety/sos`            | Live SOS feed (basic — full dashboard in Sprint 10) |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + Swagger + Postman. No Flutter code from us.

**Endpoints shipped** — full table above. Highlights:

- Preferences: `GET/PATCH /api/v1/users/me/preferences` (language, push/sms/email toggles)
- Account deletion: `POST /api/v1/users/me/account/delete-request` (+ `/cancel`, `/data-export`)
- SOS: `POST /api/v1/trips/:id/sos` — sends SMS to emergency contact + safety hotline
- Share trip: `POST /api/v1/trips/:id/share`, `DELETE /api/v1/trips/:id/share/:shareId`, public `GET /api/v1/shared-trips/:token`
- Content: `GET /api/v1/content/faq?lang=`, `/articles/:slug`, `/legal/:slug` (all public)
- Sessions: `GET /api/v1/users/me/sessions`, `DELETE /api/v1/users/me/sessions/:id`, `POST /api/v1/auth/logout/all-others`
- Force-update: middleware reads `X-App-Version` + `X-App-Platform` headers — flutter must send these on every request

**WebSocket events:** none new this sprint.

**Conventions Flutter must match:**

- Send `X-App-Version` (semver) + `X-App-Platform` (`android` | `ios`) on every API call
- Handle `426 FORCE_UPDATE_REQUIRED` globally → show force-update screen
- SOS button = red, bottom-right of trip screen, requires hold 2s to confirm
- Share trip: device contact picker → array of `+91...` phones to POST

**Artifacts:**

- Postman collection: `docs/postman/sprint-06.json`

**Unblocks mobile sprint M08 (safety + settings)** — SOS, share trip, settings page, account deletion, help center FAQ. See [`docs/mobile/sprints/MOBILE_SPRINT_08.md`](../mobile/sprints/MOBILE_SPRINT_08.md).

## Demo checklist

- [ ] User changes language to Bengali → preference persists across logins
- [ ] User taps "Delete my account" → confirmation → flag set → can still log in → sees "Account scheduled for deletion in 30d, cancel?"
- [ ] User cancels deletion → can use app normally
- [ ] Rider triggers SOS during trip → emergency contact gets SMS with location link
- [ ] Rider shares trip with one phone → recipient opens link, sees live driver position (masked)
- [ ] Admin edits an FAQ → mobile app sees updated text after cache TTL
- [ ] App with version < min → API returns 426 → app shows force-update screen

## Definition of Done

- [ ] All endpoints functional + Swagger-documented
- [ ] SMS sending uses MSG91 (or Twilio test) — log only in dev, real send in staging
- [ ] Share-trip masked output verified: no phone/PII leaks
- [ ] Account deletion soft + 30d grace window verified
- [ ] Force-update middleware tested for both `X-App-Version` lower and missing
- [ ] FAQ + 3 legal pages seeded
- [ ] e2e: signup → set prefs → request deletion → cancel → trigger SOS → share trip
- [ ] Git tag `v0.6.0-sprint-6`

## Git plan

- `feature/sprint-6-preferences`
- `feature/sprint-6-account-deletion`
- `feature/sprint-6-sos`
- `feature/sprint-6-trip-share`
- `feature/sprint-6-content-cms`
- `feature/sprint-6-sessions`
- `feature/sprint-6-force-update-middleware`

## Status

- [ ] Not started

## Delivered

## Carryover

## Notes / Blockers
