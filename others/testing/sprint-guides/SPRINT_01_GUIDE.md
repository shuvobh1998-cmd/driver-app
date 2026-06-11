# Sprint 1 — End-to-End Testing Guide

> Everything you need to take the code in `main` and exercise it locally on
> your machine. Follow top to bottom. Estimate: 30–45 min if you've never
> signed up for the providers; 10 min if you have.

---

## TL;DR — what you need

| Need                 | Purpose                      | Required?                        | Time   |
| -------------------- | ---------------------------- | -------------------------------- | ------ |
| **Supabase** project | Postgres DB                  | ✅ yes                           | 5 min  |
| **Upstash** Redis    | rate limiting + cache        | ✅ yes (or local Docker Redis)   | 5 min  |
| **Firebase** project | only for `/auth/otp/verify`  | ⚠️ optional this sprint — see §7 | 10 min |
| **JWT secrets**      | local-generated, two strings | ✅ yes                           | 30 sec |
| Sentry               | error tracking               | ❌ skip for local testing        |
| Razorpay             | payments — Sprint 8          | ❌ skip                          |
| Railway              | backend hosting              | ❌ skip until local works        |
| Vercel               | admin hosting                | ❌ skip until local works        |

---

## 1. Create the Supabase project

Follow [FREE_TIER_GUIDE.md §1](FREE_TIER_GUIDE.md#1-supabase--postgres--postgis--storage) — sections 1–8 only.
You'll come out with these four values:

| Value                       | From dashboard                                    | Goes into env        |
| --------------------------- | ------------------------------------------------- | -------------------- |
| `DATABASE_URL`              | Settings → Database → Connection string → **URI** | `backend/.env.local` |
| `SUPABASE_URL`              | Settings → API → Project URL                      | `backend/.env.local` |
| `SUPABASE_ANON_KEY`         | Settings → API → `anon` `public`                  | `backend/.env.local` |
| `SUPABASE_SERVICE_ROLE_KEY` | Settings → API → `service_role`                   | `backend/.env.local` |

**Don't skip running the PostGIS / pgcrypto SQL in step §1.6.** Even though the
Prisma migration also creates them, doing it now means the migration step
won't surprise you.

---

## 2. Create the Upstash Redis (or use local)

**Option A — Upstash** (recommended; ap-south-1 Mumbai, free tier):
follow [FREE_TIER_GUIDE.md §2](FREE_TIER_GUIDE.md#2-upstash--redis). Capture:

| Value                                         | Goes into env        |
| --------------------------------------------- | -------------------- |
| `REDIS_URL` (`rediss://default:...@...:6379`) | `backend/.env.local` |

**Option B — Local Docker Redis** (no signup, faster):

```bash
docker run -d --name rideshare-redis -p 6379:6379 redis:7-alpine
# Then in backend/.env.local:
#   REDIS_URL=redis://localhost:6379
```

---

## 3. Generate JWT secrets

Both must be **≥ 32 chars**. Run these in your terminal:

```bash
openssl rand -base64 48
# copy → JWT_ACCESS_SECRET
openssl rand -base64 48
# copy → JWT_REFRESH_SECRET
```

---

## 4. Create `backend/.env.local`

```bash
cp backend/.env.example backend/.env.local
```

Then open `backend/.env.local` and fill these in. **Leave Firebase keys empty
for now if you're skipping it (§7).**

```dotenv
# === REQUIRED ===
NODE_ENV=development
PORT=3000

DATABASE_URL=postgresql://postgres:<password>@<host>.supabase.co:5432/postgres?sslmode=require
SUPABASE_URL=https://<ref>.supabase.co
SUPABASE_ANON_KEY=<paste>
SUPABASE_SERVICE_ROLE_KEY=<paste>

REDIS_URL=redis://localhost:6379         # or Upstash rediss://...
UPSTASH_REDIS_REST_URL=                  # leave blank for local
UPSTASH_REDIS_REST_TOKEN=                # leave blank for local

JWT_ACCESS_SECRET=<paste openssl output>
JWT_REFRESH_SECRET=<paste different openssl output>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d

# === Firebase — keep blank if skipping §7, otherwise paste service-account fields ===
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

# === Optional ===
SENTRY_DSN=                              # leave blank, no-ops at runtime
ADMIN_ORIGIN=http://localhost:3001
LOG_LEVEL=debug

# === Admin seed (used by `pnpm db:seed`) ===
ADMIN_SEED_EMAIL=admin@example.com
ADMIN_SEED_PHONE=+919999999999
ADMIN_SEED_PASSWORD=ChangeMe!2026
ADMIN_SEED_FIRST_NAME=Admin
ADMIN_SEED_LAST_NAME=User
```

> ⚠ **The env validator will refuse to start the backend** if `JWT_*` or
> `FIREBASE_*` are missing. If you're skipping Firebase, set the three vars to
> a placeholder string so validation passes:
>
> ```dotenv
> FIREBASE_PROJECT_ID=local-stub
> FIREBASE_CLIENT_EMAIL=stub@local.iam.gserviceaccount.com
> FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nstub\n-----END PRIVATE KEY-----"
> ```
>
> The backend boots fine; only `/auth/otp/verify` will fail.

---

## 5. Create `admin/.env.local`

```bash
cp admin/.env.example admin/.env.local
```

Fill it in:

```dotenv
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api/v1
ADMIN_SESSION_SECRET=<openssl rand -base64 48>

# Sentry (skip for local)
NEXT_PUBLIC_SENTRY_DSN=
SENTRY_DSN=
SENTRY_AUTH_TOKEN=
SENTRY_ORG=
SENTRY_PROJECT=
```

---

## 6. Apply DB migration + seed the admin user

From the repo root:

```bash
# Apply the 0001_init migration (creates users, auth_refresh_tokens, extensions).
pnpm --filter backend prisma:migrate:deploy

# Seed your first admin user. Password is read from ADMIN_SEED_PASSWORD.
pnpm --filter backend db:seed
```

You should see `Created admin user: admin@example.com (usr_...)`. **Verify it
in Supabase** — Table Editor → `users` → one row.

If migration fails with `permission denied` on `CREATE EXTENSION`, go back to
[FREE_TIER_GUIDE.md §1.6](FREE_TIER_GUIDE.md#enable-postgis--pgcrypto) and run the SQL
manually. Then `pnpm --filter backend prisma:migrate:deploy` again.

---

## 7. (Optional) Firebase for `/auth/otp/verify`

If you don't have a Firebase project yet, follow
[FREE_TIER_GUIDE.md §3](FREE_TIER_GUIDE.md#3-firebase--phone-otp-auth--fcm) sections
1–13 and paste `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`,
`FIREBASE_PRIVATE_KEY` into `backend/.env.local`.

**Important: add at least one test phone number** in Firebase console →
Authentication → Sign-in method → Phone → "Phone numbers for testing". Use
`+919000000001` with code `123456`. Otherwise dev SMS costs money.

---

## 8. Boot both apps

In two separate terminals:

```bash
# Terminal 1 — backend on :3000
pnpm --filter backend dev

# Terminal 2 — admin on :3001
pnpm --filter admin dev
```

You should see (backend):

```
[Bootstrap] Backend listening on http://localhost:3000/api/v1
[Bootstrap] Swagger UI at http://localhost:3000/docs
```

If you see Pino's pretty-printed colored output with `[req_xxx]` prefixes,
**Feature 6 logging is working.**

---

## 9. Smoke-test each feature

Open a third terminal for `curl`. The `jq` calls are optional — pipe through
for prettier output.

### Feature 1 — scaffolding (already done by booting both apps)

✅ Pass = both `pnpm dev` commands start without errors.

### Feature 2 — infrastructure

Hit Supabase URL in browser → green project status. Hit Redis (Upstash
dashboard or `redis-cli -u $REDIS_URL ping` → `PONG`).

### Feature 3 — DB baseline

```bash
# Verify the seed worked. From repo root:
pnpm --filter backend prisma:studio
```

Prisma Studio opens at <http://localhost:5555>. Click `users` → you'll see the
admin row with `roles: [ADMIN]`, `status: ACTIVE`, a `passwordHash` starting
with `$argon2id$`.

### Feature 4 — Phone OTP endpoints

#### 4.1 `/auth/otp/send` — rate limit + audit (no SMS sent)

```bash
curl -i -X POST http://localhost:3000/api/v1/auth/otp/send \
  -H 'content-type: application/json' \
  -d '{"phone":"+919876543210"}'
```

Expected: **202** with envelope body.

```json
{
  "success": true,
  "data": { "status": "ACCEPTED", "cooldownSeconds": 60, "note": "..." },
  "meta": { "requestId": "req_...", "timestamp": "..." }
}
```

Run it **4 times in 10 minutes** — the 4th should return **429**:

```json
{ "success": false, "error": { "code": "RATE_LIMITED", ... } }
```

#### 4.2 `/auth/otp/send` — validation

```bash
curl -i -X POST http://localhost:3000/api/v1/auth/otp/send \
  -H 'content-type: application/json' \
  -d '{"phone":"not-a-phone"}'
```

Expected: **400** with `error.code: VALIDATION_ERROR`, `error.field: phone`.

#### 4.3 `/auth/otp/verify` — requires Firebase

There are 3 ways to get a Firebase ID token to feed this endpoint:

- **Easiest if you skipped Firebase:** defer. The Flutter dev integrates this
  via `firebase_auth` and posts the token here. Sprint 1 demo can skip this.
- **Quick HTML test page** (10 lines, runs in browser using Firebase JS SDK
  with reCAPTCHA + your test phone number from §7). Ask me to generate it
  when you're ready.
- **Use the Firebase Auth REST API directly** via curl — see Firebase docs
  for [verifyPhoneNumber](https://firebase.google.com/docs/reference/rest/auth#section-verify-phone-number).
  Requires a reCAPTCHA token, so awkward from CLI.

Recommended for now: defer. The other 4 auth endpoints test the same
infrastructure (JWT, DB, Redis, refresh rotation), so deferring `otp/verify`
doesn't reduce confidence much.

#### 4.4 `/auth/me` and `/auth/refresh` — see §9 Feature 5 below

These need a JWT, easiest to get one via admin login first.

### Feature 5 — Admin login (best demoed in the browser)

Open <http://localhost:3001/login> →

1. Email: `admin@example.com` (or whatever you set in `ADMIN_SEED_EMAIL`)
2. Password: your `ADMIN_SEED_PASSWORD`
3. Click **Sign in**.

Expected:

- Browser redirects to `/` (the dashboard skeleton)
- You see sidebar (Dashboard active, others greyed "soon"), topbar with your
  name + Sign out, 3 placeholder cards.
- Open DevTools → Application → Local Storage → `localhost:3001`. You'll see
  three keys: `rideshare.admin.accessToken`, `…refreshToken`, `…user`.

**Negative test:** click **Sign out**. You're booted back to `/login`. Open a
new tab to `http://localhost:3001/` directly — the AuthGuard sends you to
`/login`.

**Wrong-password test:** try `admin@example.com` with a wrong password →
form shows error "Invalid email or password" with `error.code` =
`UNAUTHENTICATED` in the network tab.

**curl version** if you prefer:

```bash
curl -s -X POST http://localhost:3000/api/v1/admin/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"admin@example.com","password":"ChangeMe!2026"}' | tee /tmp/login.json

# Extract tokens for follow-ups
ACCESS=$(jq -r '.data.accessToken' /tmp/login.json)
REFRESH=$(jq -r '.data.refreshToken' /tmp/login.json)
```

Now exercise the bearer-protected endpoints:

```bash
# /auth/me
curl -s -H "Authorization: Bearer $ACCESS" http://localhost:3000/api/v1/auth/me | jq

# /auth/refresh (rotation: returns new pair, revokes old refresh)
curl -s -X POST http://localhost:3000/api/v1/auth/refresh \
  -H 'content-type: application/json' \
  -d "{\"refreshToken\":\"$REFRESH\"}" | jq

# /auth/refresh AGAIN with the SAME (now revoked) refresh → 401
curl -i -X POST http://localhost:3000/api/v1/auth/refresh \
  -H 'content-type: application/json' \
  -d "{\"refreshToken\":\"$REFRESH\"}"
# Expect: 401, error.code "UNAUTHENTICATED"

# /auth/logout
curl -i -X POST http://localhost:3000/api/v1/auth/logout \
  -H "Authorization: Bearer $ACCESS" \
  -H 'content-type: application/json' \
  -d "{\"refreshToken\":\"$REFRESH\"}"
# Expect: 204 No Content
```

Verify in Supabase → `auth_refresh_tokens`: you'll see rows with `revoked_at`
set after rotation + logout.

### Feature 6 — Observability

#### 6.1 `/health`

```bash
curl -s http://localhost:3000/api/v1/health | jq
```

Expected (note: bare body, no envelope):

```json
{
  "status": "ok",
  "service": "backend",
  "timestamp": "2026-05-24T...",
  "uptime": 12.34,
  "checks": {
    "db": { "status": "ok", "latencyMs": 8 },
    "redis": { "status": "ok", "latencyMs": 2 }
  }
}
```

**Negative test:** stop your Redis container (or block Upstash):

```bash
docker stop rideshare-redis
curl -i http://localhost:3000/api/v1/health
```

Expected: **503** with `status: "degraded"`, `checks.redis.status: "fail"`.
Then `docker start rideshare-redis` to restore.

#### 6.2 Structured logs

Look at the backend terminal output while hitting endpoints. You should see
Pino pretty-printed lines like:

```
[14:23:01.234] INFO [req_abc123def456]: request completed
    req: { method: 'POST', url: '/api/v1/auth/otp/send' }
    res: { statusCode: 202 }
```

The `req_*` matches `meta.requestId` in the response envelope and the
`X-Request-Id` response header. **That's the correlation chain working.**

#### 6.3 Swagger

Open <http://localhost:3000/docs>. You should see **all 6 endpoints grouped
by tag** (`auth`, `admin-auth`, `health`) with request/response schemas. Click
**Authorize**, paste your `$ACCESS` token, and hit `GET /auth/me` directly
from the UI.

#### 6.4 Sentry (skip if `SENTRY_DSN` empty)

If you set a real `SENTRY_DSN`, trigger a 500 by hitting a bogus route that
fails inside a handler. The simplest way: temporarily add `throw new Error('test')`
to any controller, hit it, then revert. Open <https://sentry.io> → Issues →
your error appears with `requestId` tag.

---

## 10. Definition of Done (Sprint 1)

Tick these off when each works:

- [ ] `pnpm --filter backend dev` boots cleanly
- [ ] `pnpm --filter admin dev` boots cleanly
- [ ] `/health` returns 200 with both checks `ok`
- [ ] `/docs` shows all endpoints
- [ ] `/auth/otp/send` returns 202 → 429 after 3 hits
- [ ] `/auth/otp/send` rejects bad phone with 400 `VALIDATION_ERROR`
- [ ] Admin login form at `/login` works end-to-end → dashboard
- [ ] Sign out clears storage and bounces to `/login`
- [ ] `/auth/me` with stolen Bearer token returns 200
- [ ] `/auth/refresh` rotates (old refresh becomes 401)
- [ ] `/auth/logout` returns 204; refresh row gets `revoked_at`
- [ ] `/auth/otp/verify` — deferred to Flutter integration OR tested via HTML page

---

## 11. After local works — deploy

Once everything above works locally, follow
[FREE_TIER_GUIDE.md §5 (Railway)](FREE_TIER_GUIDE.md#5-railway--backend-hosting) and
[§6 (Vercel)](FREE_TIER_GUIDE.md#6-vercel--admin-panel-hosting). Same env values,
just pasted into their dashboards instead of `.env.local`.

After Railway deploys: hit `https://<your-railway-domain>/api/v1/health` from
your phone browser — that's the URL Flutter devs use.
