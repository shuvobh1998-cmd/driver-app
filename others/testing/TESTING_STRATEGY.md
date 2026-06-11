# Testing Strategy

> No QA on the team. This doc is your safety net.

## The pyramid (per surface)

```
                ▲
                │     Manual smoke (every sprint demo)
                │
                │     E2E / integration  (critical flows)
                │
                │     Unit  (services, utilities, math)
                ▼
```

## Coverage targets

| Surface | Unit                             | E2E / integration                               | Manual smoke                   |
| ------- | -------------------------------- | ----------------------------------------------- | ------------------------------ |
| Backend | 70% lines on services            | All critical-path endpoints                     | Per-sprint guide               |
| Admin   | None enforced                    | Optional Playwright on auth + 1 critical flow   | Full smoke before every demo   |
| Mobile  | Widget tests for forms & screens | `integration_test` on auth + booking happy path | On real device before APK ship |

## Critical paths (must never break)

### Backend

1. Auth — signup, login, refresh, logout
2. Driver online/offline + location ping
3. Ride request → matching → accept
4. Trip state machine (after Sprint 7)
5. Payment order → verify → wallet credit (after Sprint 8)
6. Scheduled trip post + seat booking (after Sprint 9)
7. Webhook signature verification (Razorpay)

### Admin

1. Login + logout
2. Driver KYC approve / reject
3. Pricing rule update
4. Trip detail loads with map
5. Payout approval workflow

### Mobile

1. Signup happy path
2. Login + token refresh
3. Booking → match → trip end → rate
4. Driver: go online → accept → arrived → start → end
5. SOS button triggers

## When to escalate

Stop building, fix immediately if any of these break in `main`:

- Auth fails (no one can log in)
- DB migration fails to apply
- Health check returns 5xx
- Race condition allows double-accept of same trip
- Payment webhook misverifies signature
- WebSocket auth bypass (any unauthenticated client receives events)
- PII leak in API response or push notification

## CI gates

| Gate       | Backend                 | Admin    | Mobile                    |
| ---------- | ----------------------- | -------- | ------------------------- |
| Lint       | required                | required | required                  |
| Type-check | required                | required | required (`dart analyze`) |
| Unit tests | required                | optional | required                  |
| E2E        | required (smoke subset) | optional | optional                  |
| Build      | required                | required | required (release flavor) |

Set in `.github/workflows/`.

## Per-sprint demo checklist

Every sprint ends with a 10-minute demo to the founder. Each sprint file has its own checklist under "Demo checklist". You can't say "Done" until every box is ticked.

## Production safety net (post-launch)

- Sentry alerts → founder + you on email
- UptimeRobot pings `/health` every 5 min
- Backups: `pg_dump` weekly to Cloudinary (manual MVP, automated post-launch)
- Razorpay webhook replay testing every release

## Tools per surface

| Surface | Test framework                      | Mock / fixture                                                     |
| ------- | ----------------------------------- | ------------------------------------------------------------------ |
| Backend | Jest + Supertest                    | Test DB (Docker Postgres+PostGIS), Redis (fakeredis or test Redis) |
| Admin   | Playwright (optional)               | MSW for API mocks                                                  |
| Mobile  | `flutter_test` + `integration_test` | `mocktail` for API mocks                                           |
| Load    | k6 (HTTP) + Artillery (WebSocket)   | hits staging env                                                   |

## Sprint-specific manual guides

[`sprint-guides/`](sprint-guides/) — full step-by-step manual testing recipes for each backend sprint. Use when you want to exercise the deployed system end-to-end after each sprint completes.
