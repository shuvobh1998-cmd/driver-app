# Sprint 10 — Notifications, Support, Hardening, Launch

> **Duration:** 2 weeks
> **Theme:** Full notification system, support tickets, user management, load testing, production deploy

## Goal

Beta-launch ready. Founder runs an end-to-end trip from a real device with push notifications for every state. 50 real drivers onboarded. Founder confidently shares the app with first riders.

## Why this sprint

Up to here, the app _works_ in dev. This sprint makes it ready for real users: notifications they actually receive, support when something goes wrong, the ability to ban bad actors, and confidence under load.

## Features

### 1. Notification system (full)

- `notifications` table (Sprint 10 DB)
- Service layer: `notificationService.send({ userId, type, channel, payload })`
- Channels: PUSH (FCM), SMS (MSG91/Fast2SMS), IN_APP
- Templates per notification type (15+ types — see list)
- User preferences: opt out of marketing pushes
- `GET /api/v1/notifications` — in-app list (paginated)
- `POST /api/v1/notifications/:id/read`
- `POST /api/v1/notifications/read-all`

### 2. FCM device token management

- `POST /api/v1/users/me/device-tokens` — register on app launch
- `DELETE /api/v1/users/me/device-tokens` — on logout
- Stale token cleanup job (FCM `Unregistered` response → delete)

### 3. Notification types covered

- `OTP_SENT` (SMS) — handled in auth, just unify here
- `KYC_APPROVED`, `KYC_REJECTED` (PUSH + IN_APP)
- `TRIP_OFFERED` (PUSH — driver)
- `TRIP_ACCEPTED` (PUSH — rider)
- `DRIVER_ARRIVED` (PUSH — rider)
- `TRIP_STARTED`, `TRIP_ENDED` (PUSH — both)
- `TRIP_CANCELLED` (PUSH — both)
- `PAYMENT_SUCCESS`, `PAYMENT_FAILED` (PUSH + IN_APP — rider)
- `PAYOUT_PROCESSED` (PUSH + SMS — driver)
- `SCHEDULED_TRIP_BOOKED` (PUSH — driver)
- `SCHEDULED_TRIP_CANCELLED_BY_DRIVER` (PUSH + SMS — rider; SMS because high-impact)
- `DEPARTURE_REMINDER` (PUSH — both, 30 min before)
- `SUPPORT_TICKET_UPDATE` (PUSH + IN_APP)

### 4. Support tickets

- `POST /api/v1/support/tickets` — create with category/subject/description, optional `tripId`
- `GET /api/v1/support/tickets/me` — user's tickets
- `GET /api/v1/support/tickets/:id` — detail with messages
- `POST /api/v1/support/tickets/:id/messages` — reply
- Admin:
  - `GET /api/v1/admin/support/tickets` — queue with filters
  - `POST /api/v1/admin/support/tickets/:id/assign` — assign to admin user
  - `POST /api/v1/admin/support/tickets/:id/messages` — reply
  - `POST /api/v1/admin/support/tickets/:id/resolve`

### 5. User management (admin)

- `GET /api/v1/admin/users` — search by phone/email/name
- `POST /api/v1/admin/users/:id/suspend` — body `{ reason, durationDays? }`
- `POST /api/v1/admin/users/:id/unsuspend`
- `POST /api/v1/admin/users/:id/ban` — permanent
- `GET /api/v1/admin/users/:id/audit` — history of admin actions

### 6. Hardening

- Rate limiting tuned per endpoint
- Helmet equivalents for Fastify
- CORS allowlist tightened
- Request body size limits enforced
- SQL injection review (Prisma protects, but raw queries audited)
- Secrets rotation procedure documented
- Sentry alerts wired to founder email
- Backup procedure (daily `pg_dump` to S3-compatible storage)

### 7. Load testing

- k6 or Artillery script simulating:
  - 100 concurrent online drivers pinging location
  - 50 ride requests/minute
  - 200 active WebSocket connections
- Identify and fix bottlenecks
- Confirm Redis + DB headroom on Railway free tier (or upgrade)

### 8. Documentation finalisation

- API docs (Swagger) reviewed and polished
- Postman collection consolidated `docs/postman/master.json`
- README updated with setup steps for new devs
- `docs/RUNBOOK.md` — common ops playbook (rotate keys, manual refund, ban abuser, restore from backup)

### 9. Launch checklist

- Razorpay live mode keys obtained (apply early in sprint)
- Domain purchased + DNS pointed
- TLS certs (Vercel + Railway handle automatically)
- Privacy policy + Terms of Service page in admin (static)
- Driver onboarding script + materials ready (founder owns)
- Founder lined up 50 drivers ready for KYC submission

## API endpoints delivered

(see Features above — extensive)

## DB migrations this sprint

1. `0028_notifications`
2. `0029_device_tokens`
3. `0030_support_tickets` + `support_ticket_messages`
4. `0031_user_admin_audit`

## Admin panel pages this sprint

| Page                     | Purpose                                            |
| ------------------------ | -------------------------------------------------- |
| `/support/tickets`       | Ticket queue                                       |
| `/support/tickets/[id]`  | Conversation view + resolve                        |
| `/users` (enhanced)      | Search + suspend/ban actions                       |
| `/users/[id]/audit`      | Admin action history on this user                  |
| `/notifications/preview` | Test sending notifications (admin tool)            |
| `/settings`              | App-wide settings (terms URL, support phone, etc.) |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + FCM payload contract + Swagger + Postman. No Flutter code from us; Flutter devs wire `firebase_messaging` against our endpoints.

**Endpoints shipped (rider/driver):**

- Notifications: `GET /api/v1/notifications`, `POST /api/v1/notifications/:id/read`, `/read-all`, `GET /api/v1/notifications/unread-count`
- FCM tokens: `POST /api/v1/users/me/device-tokens` (register on launch), `DELETE` on logout
- Support: `POST /api/v1/support/tickets`, `GET /api/v1/support/tickets/me`, `GET /api/v1/support/tickets/:id`, `POST /api/v1/support/tickets/:id/messages`
- Lost item: `POST /api/v1/support/lost-item`

**Push payload contract (FCM data message):**

```json
{
  "type": "TRIP_OFFERED" | "TRIP_ACCEPTED" | "DRIVER_ARRIVED" | "TRIP_STARTED" | "TRIP_ENDED" | "TRIP_CANCELLED" | "PAYMENT_SUCCESS" | "PAYMENT_FAILED" | "PAYOUT_PROCESSED" | "SCHEDULED_TRIP_BOOKED" | "SCHEDULED_TRIP_CANCELLED_BY_DRIVER" | "DEPARTURE_REMINDER" | "SUPPORT_TICKET_UPDATE" | "KYC_APPROVED" | "KYC_REJECTED",
  "deepLink": "/trips/trp_abc",
  "title": "...",
  "body": "...",
  "data": { "tripId": "...", ... }
}
```

**Conventions Flutter must match:**

- Register device token on every app launch + on FCM token refresh
- Unregister on logout
- Foreground push → in-app banner (use `awesome_notifications` or similar)
- Background push tap → deep-link routing via `deepLink` field
- Support marketing-push opt-out via Sprint 6 preferences endpoint

**Artifacts:**

- Postman collection: `docs/postman/sprint-10.json` + consolidated `docs/postman/master.json`
- FCM setup guide (`google-services.json` / `GoogleService-Info.plist`) in [`docs/mobile/FLUTTER_HANDOFF.md`](../mobile/FLUTTER_HANDOFF.md)
- All notification types + payloads documented in [`docs/REALTIME_EVENTS.md`](../REALTIME_EVENTS.md)

**Unblocks mobile sprint M08** — notification inbox, push handling, support tickets, beta launch polish. See [`docs/mobile/sprints/MOBILE_SPRINT_08.md`](../mobile/sprints/MOBILE_SPRINT_08.md).

## Demo checklist

- [ ] Real Android device + real driver + real rider
- [ ] Driver online → request → push received → accept → push to rider
- [ ] Trip completes → payment success push
- [ ] Rider opens support ticket about lost item → admin replies → rider gets push
- [ ] Admin bans a test user → user can't log in (gets BANNED error)
- [ ] Load test screenshot — system stays under 500ms p99 for ride request
- [ ] Sentry shows zero unhandled errors in last 24h

## Definition of Done

- [ ] All notification types fire correctly end-to-end
- [ ] FCM token lifecycle (register/unregister/stale cleanup)
- [ ] Support flow works both directions
- [ ] User ban prevents login (auth check)
- [ ] Load test passes targets (define in sprint)
- [ ] Daily DB backup verified (restore tested at least once)
- [ ] Live Razorpay keys configured in prod env
- [ ] Domain + TLS live
- [ ] RUNBOOK committed
- [ ] Git tag `v1.0.0-beta`

## Git plan

- `feature/sprint-10-notification-service`
- `feature/sprint-10-fcm-tokens`
- `feature/sprint-10-notification-types`
- `feature/sprint-10-support-tickets`
- `feature/sprint-10-user-management`
- `feature/sprint-10-hardening`
- `feature/sprint-10-load-test`
- `feature/sprint-10-runbook`
- `feature/sprint-10-launch-prep`

## Status

- [ ] Not started

## Delivered

## Carryover

> Beyond v1: surge pricing, multi-city, referrals, etc. — see ROADMAP.md "Out of MVP".

## Notes / Blockers
