# 100% Free Stack Guide — Dev & Testing Phase

> Goal: every backend service runs without paying a rupee until you go to real users. This is the actual stack and setup steps.

## Recommended free stack (final picks)

| Layer                             | Service                      | Free tier                                     | Why this one                                                                  |
| --------------------------------- | ---------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------- |
| Backend hosting                   | **Fly.io**                   | 3 shared VMs, always-on, 3GB volume           | Truly always-on (no cold starts); card on file but no charge inside free tier |
| Backup backend host               | **Render**                   | 750 hrs/mo web service                        | Easier setup; **cold start ~30s** after 15 min idle                           |
| Database (Postgres + PostGIS)     | **Supabase**                 | 500MB DB, 1GB storage, pauses after 1 wk idle | PostGIS included; integrated storage + auth                                   |
| Redis                             | **Redis Cloud** (redis.io)   | 30MB, full ACL incl. Lua scripts              | BullMQ needs `EVALSHA` — Upstash free blocks it                               |
| Admin panel hosting               | **Vercel**                   | Unlimited Next.js hobby                       | Native Next.js support                                                        |
| File storage (KYC, photos)        | **Cloudinary**               | 25GB storage + transforms                     | More room than Supabase Storage; image CDN included                           |
| Auth (phone OTP)                  | **Firebase Auth**            | 10k phone OTP / month                         | Generous; you'll never hit it in dev                                          |
| Push notifications                | **Firebase Cloud Messaging** | Unlimited, forever                            | Free always                                                                   |
| SMS (non-OTP)                     | Skip in dev                  | —                                             | Use console logs / Firebase OTP only                                          |
| Maps (tiles)                      | **OpenStreetMap**            | Free                                          | Direct tile fetch via Leaflet/Mapbox-gl                                       |
| Geocoding                         | **Nominatim** (OSM)          | 1 req/sec (must respect)                      | Free; rate-limit yourself                                                     |
| Routing                           | **OSRM public demo**         | Free, fair use                                | Distance/duration/polyline                                                    |
| Map fallback (for Flutter map UI) | **Mapbox**                   | 50k map loads/mo                              | If OSM tiles look bad                                                         |
| Payments                          | **Razorpay test mode**       | Free forever (test)                           | Real flow, fake money                                                         |
| Error tracking                    | **Sentry**                   | 5k events/mo                                  | Plenty for dev                                                                |
| Uptime monitoring                 | **UptimeRobot**              | 50 monitors, 5-min interval                   | Keeps Render free tier warm too                                               |
| CI / CD                           | **GitHub Actions**           | 2000 min/mo (private repo)                    | Public repo = unlimited                                                       |
| Postman / API testing             | **Postman**                  | Free workspace                                | Share collection with team                                                    |
| Domain (dev)                      | Use provided subdomain       | Free                                          | `*.fly.dev`, `*.vercel.app` etc.                                              |

---

## Setup order (do in this sequence)

### 1. Database — Supabase

1. supabase.com → New Project (free org)
2. Name: `rideshare-dev`, region: `ap-south-1` (Mumbai — closest to Kolkata)
3. SQL editor → run:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE EXTENSION IF NOT EXISTS pgcrypto;
   ```
4. Settings → Database → copy "Connection string (URI)" → this is your `DATABASE_URL`
5. **Important:** Supabase free tier _pauses_ the database after 1 week of inactivity. Just open the dashboard once a week to keep it alive, or hit any endpoint daily.

### 2. Redis — Redis Cloud

1. redis.io → Try free → Sign up
2. Create database, **free 30MB** plan, region close to backend host (Mumbai/Singapore)
3. Settings → copy public endpoint and password
4. Build `REDIS_URL`: `redis://default:<password>@<host>:<port>`
5. Test: `redis-cli -u $REDIS_URL ping` → `PONG`

### 3. Firebase (Auth + FCM)

1. console.firebase.google.com → Add project: `rideshare-dev`
2. Enable Authentication → Sign-in method → Phone
3. Add test numbers (so you don't burn OTP quota in dev): Auth → Settings → "Phone numbers for testing" → add `+91 XXXX… → 123456`
4. Project Settings → Service Accounts → Generate new private key (download JSON)
5. From the JSON, extract:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_PRIVATE_KEY` (paste with `\n` literals preserved — wrap in double quotes)
6. Cloud Messaging is enabled automatically; FCM server key is in same Service Account

### 4. Cloudinary (file storage)

1. cloudinary.com → Sign up free
2. Dashboard → copy `cloud_name`, `api_key`, `api_secret` → `.env`
3. Create unsigned upload preset called `kyc-docs` (Settings → Upload → Add upload preset)
4. Use Cloudinary's Node SDK in backend; sign uploads server-side for KYC (private), unsigned for public stuff

### 5. Razorpay (payments — test mode)

1. razorpay.com → Sign up
2. Dashboard → Test Mode toggle (top right)
3. Settings → API Keys → Generate Test Keys → save `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`
4. Settings → Webhooks → add webhook for your backend URL (set after deploy): `https://<your-fly-app>.fly.dev/api/v1/webhooks/razorpay`
5. Save `RAZORPAY_WEBHOOK_SECRET`

### 6. Sentry (errors)

1. sentry.io → Free → New Project → Node.js → name `rideshare-backend`
2. Copy DSN → `SENTRY_DSN`
3. Second project for admin: Next.js → `SENTRY_DSN_ADMIN`

### 7. Backend hosting — Fly.io

1. Install CLI: `curl -L https://fly.io/install.sh | sh`
2. `fly auth signup` (card required, no charge inside free tier)
3. From `backend/`:
   ```bash
   fly launch --no-deploy
   ```

   - App name: `rideshare-backend-dev`
   - Region: `bom` (Mumbai)
   - Postgres / Redis: **NO** (we use Supabase / Redis Cloud)
4. Set secrets:
   ```bash
   fly secrets set DATABASE_URL="..." REDIS_URL="..." JWT_ACCESS_SECRET="..." \
     JWT_REFRESH_SECRET="..." FIREBASE_PROJECT_ID="..." FIREBASE_CLIENT_EMAIL="..." \
     FIREBASE_PRIVATE_KEY="..." RAZORPAY_KEY_ID="..." RAZORPAY_KEY_SECRET="..." \
     RAZORPAY_WEBHOOK_SECRET="..." CLOUDINARY_URL="..." SENTRY_DSN="..." NODE_ENV=production
   ```
5. Add `Dockerfile` in `backend/`:
   ```dockerfile
   FROM node:20-alpine
   WORKDIR /app
   COPY package.json pnpm-lock.yaml ./
   RUN corepack enable && pnpm install --frozen-lockfile
   COPY . .
   RUN pnpm prisma generate && pnpm build
   EXPOSE 3000
   CMD ["node", "dist/main"]
   ```
6. `fly deploy`
7. Your URL: `https://rideshare-backend-dev.fly.dev`

### 8. Admin panel hosting — Vercel

1. vercel.com → Import Git Repo → pick `admin/` folder
2. Env vars:
   ```
   NEXT_PUBLIC_API_BASE_URL=https://rideshare-backend-dev.fly.dev/api/v1
   NEXT_PUBLIC_MAPBOX_TOKEN=...   (if using Mapbox in admin)
   ```
3. Deploy. URL: `https://rideshare-admin-dev.vercel.app`

### 9. UptimeRobot (keeps things warm + alerts)

1. uptimerobot.com → Sign up free
2. Add monitor: HTTP(s) → `https://rideshare-backend-dev.fly.dev/api/v1/health` → every 5 min
3. Add monitor: admin URL
4. Alerts → email yourself + founder

---

## What to give Flutter devs

Create `docs/FLUTTER_HANDOFF.md` with this content (template below) and share with the 2 devs:

```
Base URL:        https://rideshare-backend-dev.fly.dev/api/v1
Health check:    https://rideshare-backend-dev.fly.dev/api/v1/health
Swagger UI:      https://rideshare-backend-dev.fly.dev/docs
WebSocket:       wss://rideshare-backend-dev.fly.dev
Postman:         https://www.postman.com/<workspace>/rideshare/collection/<id>
Test phone:      +91 99999XXXXX  OTP 123456 (configured in Firebase test numbers)
Admin panel:     https://rideshare-admin-dev.vercel.app
                 login: <admin email> / <password>
```

Add a few real test users you've created so they can log in without going through OTP flow if Firebase test numbers aren't enough.

---

## Free-tier traps (avoid these)

| Service           | Trap                               | Mitigation                                                   |
| ----------------- | ---------------------------------- | ------------------------------------------------------------ |
| Supabase          | Pauses DB after 1 week idle        | UptimeRobot ping daily / weekly visit                        |
| Redis Cloud       | 30MB ceiling                       | Don't store large blobs in Redis; geo + cache only           |
| Fly.io            | 3 shared VMs total across all apps | Don't run extra fly apps                                     |
| Render (if used)  | Cold start ~30s after 15 min idle  | UptimeRobot 10-min ping keeps warm                           |
| Firebase Auth OTP | 10k/mo cap                         | Use test numbers in dev; don't burn quota on automated tests |
| Nominatim         | 1 req/sec hard cap, 403 on bad UA  | Rate-limit client + custom User-Agent header                 |
| Razorpay          | Test webhooks need public URL      | Use Fly.io URL, not localhost                                |
| Cloudinary        | 25GB, 25k transforms/mo            | Don't generate thousands of thumbnails in dev                |
| Vercel            | 100GB bandwidth/mo                 | Admin panel is small; you won't hit it                       |
| GitHub Actions    | 2000 min/mo private repo           | Cache `node_modules`, skip CI on doc-only PRs                |

---

## When to start paying (cost ramp)

Don't pay anything until **all three** of these are true:

1. You have ≥ 20 verified real drivers actively going online
2. ≥ 100 daily ride requests
3. Founder confirms ready for public beta

At that point, in order of priority to upgrade:

| 1st | **Supabase Pro** (~$25/mo) | DB pause kills you in prod |
| 2nd | **Razorpay live** (no setup fee, 2% per txn) | Required for real money |
| 3rd | **Fly.io paid VM** | If free tier slows down |
| 4th | **Sentry paid** | Only if you hit 5k events |
| 5th | **OLA Maps** or **Google Maps** | When OSM tiles look unprofessional |

Everything else (FCM, Vercel hobby, Cloudinary, UptimeRobot, GitHub Actions, Redis Cloud 30MB) is genuinely free at MVP scale.

---

## Daily / weekly habits (free-tier hygiene)

- **Daily:** check UptimeRobot dashboard for any flapping
- **Daily:** open Supabase dashboard once to prevent pause
- **Weekly:** check Sentry for new error spikes
- **Weekly:** check Fly.io / Vercel / Render usage to see how close to limits
- **Monthly:** rotate test data if Cloudinary fills up

---

## What NOT to use in dev

- ❌ AWS / GCP / Azure managed services — paid from day 1
- ❌ Heroku — no free tier anymore
- ❌ Upstash free Redis — blocks Lua/`EVALSHA` → BullMQ broken
- ❌ Google Maps Platform — even free quota requires card and is small
- ❌ Twilio for OTP — paid per OTP; use Firebase
- ❌ MongoDB Atlas free for primary DB — you need PostGIS, not Mongo
