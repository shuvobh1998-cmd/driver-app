# Sprint 1 — Foundation

> **Duration:** 2 weeks
> **Theme:** Bootstrap backend + admin, set up DB, ship phone-OTP login

## Goal

Founder logs into the admin panel and sees a user successfully register via the deployed API.

## Why this sprint

Nothing else moves until the skeleton exists: repos, deploys, DB, auth. Flutter devs cannot start integrating real APIs without (a) a public URL and (b) registration + login endpoints. This sprint is the unblocker.

## Features

### 1. Repo & project scaffolding

- `backend/` — NestJS 11 + Fastify, TypeScript strict, ESLint + Prettier + Husky
- `admin/` — Next.js 15 (React 19) App Router + Tailwind v4 + shadcn (new CLI) init
- Root `package.json` workspace (pnpm 10), Node 22 LTS
- `.env.example` in both apps

### 2. Infrastructure setup

- Supabase project created, PostGIS extension enabled
- Upstash Redis created
- Railway project linked to GitHub, auto-deploy on `main`
- Vercel project linked for admin panel
- Sentry projects (backend + frontend)
- Firebase project created (Auth + FCM enabled)

> **Status:** Setup checklist + env keys delivered — see [docs/FREE_TIER_GUIDE.md](../FREE_TIER_GUIDE.md). Account creation in each provider's dashboard is a manual step the developer must complete; credentials get pasted into `backend/.env.local` and `admin/.env.local` plus Fly/Vercel variable panels.

### 3. Database baseline

- Prisma init
- Migration 1: `users`, `auth_refresh_tokens` tables
- Seed script: 1 admin user

### 4. Auth — Phone OTP

- `POST /api/v1/auth/otp/send` — sends OTP via Firebase
- `POST /api/v1/auth/otp/verify` — verifies code, returns JWT pair, creates `users` row if new
- `POST /api/v1/auth/refresh` — rotates refresh token
- `POST /api/v1/auth/logout` — revokes refresh token
- `GET /api/v1/auth/me` — returns current user

### 5. Admin login

- `POST /api/v1/admin/auth/login` — email + password (argon2), returns JWT
- Admin panel: login page → dashboard skeleton (sidebar, top bar, empty home)

### 6. Observability baseline

- Health endpoint `GET /api/v1/health` — checks DB + Redis
- Swagger UI at `/docs`
- Pino structured logs
- Sentry SDK wired (backend + admin)
- Request ID middleware (UUID per request, in logs + error envelope)

### 7. CI/CD

- GitHub Actions: lint, typecheck, test on PR
- Railway auto-deploys `main`
- Vercel auto-deploys `main`

## API endpoints delivered

| Method | Path                       | Auth    | Purpose                    |
| ------ | -------------------------- | ------- | -------------------------- |
| GET    | `/api/v1/health`           | none    | Service health             |
| POST   | `/api/v1/auth/otp/send`    | none    | Send OTP to phone          |
| POST   | `/api/v1/auth/otp/verify`  | none    | Verify OTP, get JWT pair   |
| POST   | `/api/v1/auth/refresh`     | refresh | Rotate access token        |
| POST   | `/api/v1/auth/logout`      | bearer  | Revoke refresh token       |
| GET    | `/api/v1/auth/me`          | bearer  | Current user               |
| POST   | `/api/v1/admin/auth/login` | none    | Admin email+password login |
| GET    | `/docs`                    | none    | Swagger UI                 |

## DB migrations this sprint

1. `0001_init` — extensions (postgis, pgcrypto), `users`, `auth_refresh_tokens`

## Admin panel pages this sprint

| Page            | Purpose                                     |
| --------------- | ------------------------------------------- |
| `/login`        | Admin email + password login                |
| `/` (dashboard) | Empty dashboard with sidebar                |
| `/users`        | Table of users (paginated, search by phone) |

## API for Mobile (what Flutter devs consume)

> **Our mobile deliverable = these endpoints + Swagger + Postman.** No Flutter code from us; Flutter devs build the UI against this contract.

**Endpoints shipped:**

- `POST /api/v1/auth/otp/send` — phone → SMS via Firebase
- `POST /api/v1/auth/otp/verify` — returns `{ accessToken, refreshToken, user }`
- `POST /api/v1/auth/refresh` — rotate access token
- `POST /api/v1/auth/logout` — revoke refresh
- `GET /api/v1/auth/me` — current user
- `GET /api/v1/health` — splash screen reachability check

**WebSocket events:** none yet.

**Artifacts:**

- Dev API URL (Fly.io): `https://rideshare-backend-dev.fly.dev/api/v1`
- Swagger live at `/docs`
- Postman collection: `docs/postman/sprint-01.json`

**Unblocks mobile sprint M01** — splash, OTP send/verify, token storage. See [`docs/mobile/sprints/MOBILE_SPRINT_01.md`](../mobile/sprints/MOBILE_SPRINT_01.md).

## Demo checklist (for founder, end of sprint)

- [ ] Open admin panel URL, log in
- [ ] Trigger `POST /auth/otp/send` from Postman with your phone → receive SMS
- [ ] Trigger `POST /auth/otp/verify` → see new user appear in admin Users table
- [ ] Show that the same admin URL works from founder's phone browser
- [ ] Show Swagger at `/docs`

## Definition of Done

- [ ] All endpoints in the table above return correct responses (success + error)
- [ ] e2e test covers OTP send → verify → me flow
- [ ] Backend deployed to Railway with public URL
- [ ] Admin panel deployed to Vercel
- [ ] CI passing on `main`
- [ ] Swagger UI live
- [ ] Postman collection in repo
- [ ] Sentry receiving errors (test by triggering a 500)
- [ ] Health check returns DB + Redis status
- [ ] All `.env.example` keys documented
- [ ] Git tag `v0.1.0-sprint-1` pushed

## Git plan

| Branch                           | Commits (one per feature)                                                                                                                                                   |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `feature/sprint-1-scaffold`      | `chore(infra): bootstrap nest+fastify backend`, `chore(infra): bootstrap next admin panel`                                                                                  |
| `feature/sprint-1-db`            | `db(users): add users + refresh_tokens tables`                                                                                                                              |
| `feature/sprint-1-auth-otp`      | `feat(auth): send OTP via firebase`, `feat(auth): verify OTP and issue jwt`, `feat(auth): refresh token rotation`, `feat(auth): logout endpoint`, `feat(auth): me endpoint` |
| `feature/sprint-1-admin-login`   | `feat(admin): email password login`, `feat(admin): dashboard skeleton`, `feat(admin): users list page`                                                                      |
| `feature/sprint-1-observability` | `feat(infra): health endpoint`, `chore(infra): pino logging + sentry`, `docs(infra): swagger ui`                                                                            |
| `feature/sprint-1-ci`            | `ci: lint typecheck test on PR`                                                                                                                                             |

## Status

- [ ] Not started
- [ ] In progress
- [x] Done (code-side; SaaS sign-ups + dashboard linking still up to developer)

### Feature progress

- [x] 1. Repo & project scaffolding — commit `6d99867`
- [x] 2. Infrastructure setup — checklist + env keys committed; manual SaaS sign-ups pending developer
- [x] 3. Database baseline — Prisma 6, schema + 0001_init migration + admin seed (commits pending push)
- [x] 4. Auth — Phone OTP — 5 endpoints, JWT pair + refresh rotation, Firebase ID-token verification, response envelope + global error filter + Swagger docs
- [x] 5. Admin login — backend POST /admin/auth/login (argon2 + role gate), admin panel login page + dashboard skeleton (sidebar/topbar/cards), client-side AuthGuard
- [x] 6. Observability baseline — Pino structured logs (json prod / pretty dev / silent test), @sentry/node backend + @sentry/nextjs admin, /health upgraded to check DB + Redis (200/503), 5xx auto-forwarded to Sentry with request-id tag
- [x] 7. CI/CD — `.github/workflows/ci.yml` (lint + typecheck + unit + e2e + build on every PR and push to `main`). Fly.io + Vercel auto-deploy on push to `main` once the repo is linked in their dashboards (see FREE_TIER_GUIDE.md)

## Delivered

> Fill at end of sprint with: shipped endpoints, tables created, decisions made, links to merged PRs.

## Carryover

> Anything pushed to Sprint 2.

## Notes / Blockers

> Capture decisions, gotchas, founder feedback.

### Security TODO (post-MVP)

- **Admin panel token storage.** Feature 5 stores access + refresh tokens in
  `localStorage` (XSS-vulnerable). Acceptable for MVP since access tokens are
  short-lived (15m) and the admin panel will sit behind Vercel auth + IP
  allowlist in prod. Move the refresh token to an httpOnly cookie set by the
  backend (`Set-Cookie` on `/admin/auth/login`) and keep access in memory once
  we're past MVP. Tracked here so we don't forget.
- **Admin panel logout.** Topbar's "Sign out" only clears `localStorage`. Wire
  it to call `POST /api/v1/auth/logout` with the refresh token so the
  server-side `auth_refresh_tokens` row gets revoked. Out of scope for Sprint 1
  because the admin panel doesn't yet have a global API client with refresh-
  token rotation logic.
