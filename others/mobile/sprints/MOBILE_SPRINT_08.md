# Mobile Sprint M08 — Notifications, Safety, Support, Launch Polish

> **Duration:** 2 weeks
> **Goal:** Beta-ready apps. End-to-end ride with real push notifications, SOS button works, rider can share trip with mom, support ticket round-trips, both APKs/IPAs submitted to TestFlight / Play Internal Testing.

## Scope

### Notifications

- FCM registration on app launch (POST device token)
- Foreground push handling (show in-app banner via `awesome_notifications`)
- Background push opens app at deep link
- Notification inbox screen (paginated, mark read)
- Unread badge in home tab bar
- Tap notification → deep-link routing

### Safety

- SOS button on trip screen (red, bottom-right, requires hold 2s to confirm)
- SOS confirmation modal w/ optional notes
- Share trip: contact picker → select contacts → SMS link sent
- Active shares list + revoke

### Support

- "Help" tab in drawer
- FAQ accordion (cached from `/content/faq`)
- Help articles (search + open)
- Create ticket form (category, subject, description, optional trip selector)
- My tickets list + detail conversation
- Lost item reporting (subtype)

### Settings

- Language picker (en / bn / hi) — uses `flutter_localizations`
- Notification preferences (marketing push/sms toggles)
- About / version
- Logout from all other devices
- Sessions list
- Delete my account flow (confirmation, 30-day grace warning)
- Cancel pending deletion banner

### Launch polish

- Empty states for every list (no rides, no notifications, no bookings, no payouts)
- Loading skeletons
- Error states with retry buttons
- App icon + splash screen final assets
- Privacy policy + Terms screens (pull from CMS)
- Onboarding tutorial (3 slides on first launch)
- Build signed APK + IPA
- Set up Play Internal Testing track
- Set up TestFlight

## Endpoints integrated

- `POST /api/v1/users/me/device-tokens`
- `DELETE /api/v1/users/me/device-tokens`
- `GET /api/v1/notifications`
- `POST /api/v1/notifications/:id/read`
- `POST /api/v1/notifications/read-all`
- `GET /api/v1/notifications/unread-count`
- `POST /api/v1/trips/:id/sos`
- `POST /api/v1/trips/:id/share`
- `DELETE /api/v1/trips/:id/share/:shareId`
- `GET /api/v1/content/faq`
- `GET /api/v1/content/articles/:slug`
- `GET /api/v1/content/legal/:slug`
- `POST /api/v1/support/tickets`
- `GET /api/v1/support/tickets/me`
- `GET /api/v1/support/tickets/:id`
- `POST /api/v1/support/tickets/:id/messages`
- `POST /api/v1/support/lost-item`
- `GET/PATCH /api/v1/users/me/preferences`
- `POST /api/v1/users/me/account/delete-request`
- `POST /api/v1/users/me/account/delete-request/cancel`
- `GET /api/v1/users/me/sessions`
- `DELETE /api/v1/users/me/sessions/:id`
- `POST /api/v1/auth/logout/all-others`

## Acceptance

- [ ] Trip ends → rider gets push within 5s
- [ ] SOS triggers → emergency contact gets SMS
- [ ] Share trip → link works in incognito browser (masked driver name)
- [ ] Support ticket → admin reply → rider sees it
- [ ] Language switch to Bengali → main screens translated
- [ ] Account deletion → 30-day grace flow tested
- [ ] APK on Play Internal Testing
- [ ] IPA on TestFlight
- [ ] Founder + 5 internal testers can install and run

## Status

- [x] Backend API delivered + verified end-to-end (Flutter app build, TestFlight/Play, i18n strings are the mobile team's tasks)

## Delivered

> Our deliverable = the backend endpoints + WS events + Swagger the Flutter team
> consumes. New `safety`, `support`, `content`, `sms` modules; notifications +
> users + auth extended. Migrations `0020` (inbox/safety/support/settings) + `0021`
> (ticket→trip FK).

**Notifications** — unified `notify()` persists an inbox row + emits WS
`notification.received` + sends FCM in one call. `GET /notifications`,
`GET /notifications/unread-count`, `POST /notifications/:id/read`,
`POST /notifications/read-all`, `POST|DELETE /users/me/device-tokens`.

**Safety** — `POST /trips/:id/sos` records an SosEvent + SMSes the user's
emergency contacts + alerts the counterparty in-app. `POST /trips/:id/share`
mints a tokenized link + SMSes recipients; `GET /trips/:id/shares`;
`DELETE /trips/:id/share/:shareId`. Public `GET /shared-trips/:token` returns a
driver-masked live view (404 on revoke/expire). `SmsModule` abstraction
(`console` dev provider | `msg91`).

**Support + content** — `POST /support/tickets`, `POST /support/lost-item`,
`GET /support/tickets/me`, `GET /support/tickets/:id`, `POST
/support/tickets/:id/messages` (owner→user reply; admin/support→staff reply,
status PENDING + `SUPPORT_TICKET_UPDATE` notification). Admin queue `GET
/admin/support/tickets` + `PATCH` status. Public `GET /content/{faq,articles/:slug,
legal/:slug}` with locale fallback to `en`.

**Settings** — `GET|PATCH /users/me/preferences` (language + marketing toggles),
`POST /users/me/account/delete-request` (30-day reversible grace) + `.../cancel`,
`GET /users/me/sessions`, `DELETE /users/me/sessions/:id`, `POST
/auth/logout/all-others` (keeps the caller's session).

**End-to-end verification** (real Supabase + Redis): content FAQ **en + bn** +
legal (public, no auth); SOS → **1 contact SMSed** + driver inbox
`SAFETY_SOS_TRIGGERED` + unread badge 1; share → masked public view (driver
"Arjun", plate `WB12 •• 4321`) → revoke → **404**; support ticket (trip-linked) →
admin staff reply → status **PENDING** + rider sees reply + `SUPPORT_TICKET_UPDATE`
→ resolve; lost-item under **LOST_ITEM**; notification read + read-all → unread
**0**; preferences get/patch (bn, push off); account deletion **+30 days** + cancel

- re-cancel **409**; device-token register/unregister **204**; sessions list 3 →
  revoke 1 → logout-all-others (keep one) → **1 remains**. 364 unit tests green.

## Notes

- **SMS is the `console` provider in dev** — SOS/share messages are logged, not
  sent (no gateway creds). `contactsNotified`/`recipientsNotified` count accepted
  sends. Wire `msg91` (`MSG91_AUTH_KEY`) for prod; the abstraction is in place.
- **`notify()` is the mechanism, not yet wired into every lifecycle event.** SOS
  and support use it live; wiring it into trip-end / payment-success / KYC etc.
  (so "trip ends → push within 5s" fires automatically) is a small follow-up —
  call `notify()` at those existing emit points.
- **Account deletion is a soft schedule** — it stamps `deleteRequestedAt`/
  `deleteScheduledAt` (30-day grace, reversible). The actual purge after grace
  needs a scheduled job (BullMQ repeatable) — deferred; the flow + reversal are done.
- **Sessions = refresh tokens.** New tokens carry a `ses_*` id; pre-existing
  tokens (minted before migration 0020) fall back to `ses_<numericId>` on read.
- **Out of backend scope** (Flutter team): empty states, skeletons, onboarding
  slides, app icon/splash, i18n string bundles, signed APK/IPA, Play Internal
  Testing + TestFlight. The backend gives them every endpoint those screens need.
