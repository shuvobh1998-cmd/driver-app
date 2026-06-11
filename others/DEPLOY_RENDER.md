# Deploy to Render (100% free, no credit card)

> Fly.io trial ended (requires card). Koyeb removed their free tier (now $30/mo). **Render.com** is the cleanest remaining no-card option in 2026. The only downside — free web services spin down after 15 min idle — is solved by a free UptimeRobot ping every 5 min.

## Why Render

- **No credit card** at signup (GitHub OAuth only)
- **Free web service** — 512MB RAM, 0.1 vCPU
- **Native Docker** — uses your existing `Dockerfile` as-is
- **Singapore region** available (good for Indian latency)
- **Auto-deploy on push** to GitHub
- **Free TLS** + free `*.onrender.com` subdomain

## Free-tier limits

| Resource   | Free limit                        | Workaround if hit                                |
| ---------- | --------------------------------- | ------------------------------------------------ |
| Services   | unlimited free services           | n/a                                              |
| RAM        | 512MB                             | enough for NestJS+Prisma                         |
| vCPU       | 0.1 burstable                     | enough for dev/beta                              |
| Bandwidth  | 100GB outbound/month              | hard cap                                         |
| Cold start | spins down after 15min idle       | **UptimeRobot pings every 5min — keeps it warm** |
| Build time | 500 build min/month               | ~10 builds/day max                               |
| Postgres   | 1 free DB for 90 days, then $7/mo | use **Supabase** instead (you already do)        |
| Redis      | Render free Redis ended           | use **Redis Cloud free 30MB** (you already do)   |

You're already on Supabase + Redis Cloud, so the only Render resource you need is the web service.

---

## Step 1 — Sign up

1. Open https://dashboard.render.com/register
2. Click **Sign up with GitHub**
3. Authorize Render to read your repos
4. Skip the onboarding survey

## Step 2 — Create the web service

1. Dashboard → **New +** → **Web Service**
2. Connect to your `ride_sharing_app` GitHub repo
3. Fill in:
   - **Name:** `rideshare-backend-dev`
   - **Region:** **Singapore**
   - **Branch:** `main`
   - **Root Directory:** (leave blank — Dockerfile is at repo root)
   - **Runtime:** **Docker**
   - **Dockerfile Path:** `./Dockerfile`
   - **Docker Build Context Directory:** `.`
   - **Instance Type:** **Free**

4. Scroll to **Advanced**:
   - **Health Check Path:** `/api/v1/health`
   - **Auto-Deploy:** **Yes** (deploys on every push to `main`)
   - **Port:** Render auto-detects from `PORT` env var (your app listens on `3000`)

Do NOT click "Create Web Service" yet — add env vars first.

## Step 3 — Add environment variables

Scroll to **Environment Variables** → **Add from .env**.

Paste all env vars in `KEY=value` format, one per line. Use the same values you set on Fly (your `/tmp/fly-secrets.env`).

**Required env vars** (full list in [`backend/ENV_VARS.md`](backend/ENV_VARS.md)):

```bash
NODE_ENV=production
PORT=3000

# Database (Supabase — same as before)
DATABASE_URL=postgresql://postgres:<password>@<host>.supabase.co:5432/postgres

# Redis Cloud (same as before)
REDIS_URL=redis://default:<password>@<host>:<port>

# Auth
JWT_ACCESS_SECRET=<your-secret>
JWT_REFRESH_SECRET=<your-secret>
ADMIN_ORIGIN=https://rideshare-backend-dev.onrender.com

# Firebase (paste full JSON service account, base64-encoded)
FIREBASE_SERVICE_ACCOUNT_BASE64=<base64-string>

# Cloudinary
CLOUDINARY_CLOUD_NAME=<name>
CLOUDINARY_API_KEY=<key>
CLOUDINARY_API_SECRET=<secret>

# Razorpay (test mode)
RAZORPAY_KEY_ID=rzp_test_<id>
RAZORPAY_KEY_SECRET=<secret>
RAZORPAY_WEBHOOK_SECRET=<secret>

# Storage
STORAGE_PROVIDER=supabase
STORAGE_BUCKET_PUBLIC=public-uploads
STORAGE_BUCKET_PRIVATE=kyc-docs
KYC_DOC_NUMBER_KEY=<base64-of-32-bytes>

# Supabase service role
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<key>

# Nominatim
NOMINATIM_USER_AGENT=Mozilla/5.0 (compatible; rideshare-backend-dev; contact@example.com)

# Sentry
SENTRY_DSN=https://<dsn>@sentry.io/<project>
```

## Step 4 — Deploy

Click **Create Web Service**.

Render will:

1. Clone your repo
2. Build the Docker image (~5–8 min first time — Render's free builder is slower than Fly's)
3. Run the container — your Dockerfile's CMD runs `pnpm prisma migrate deploy && node dist/main.js`
4. Health-check `/api/v1/health` — flips to "Live" when it passes

Watch the **Logs** tab. You should see:

```
Prisma migrations applied
Nest application successfully started
Listening on http://0.0.0.0:3000
==> Your service is live 🎉
```

## Step 5 — Verify

Render assigns a URL like `https://rideshare-backend-dev.onrender.com` (or with a random suffix if the name's taken).

```bash
curl https://rideshare-backend-dev.onrender.com/api/v1/health
# → {"success":true,"data":{"db":"ok","redis":"ok"}}

# Swagger
open https://rideshare-backend-dev.onrender.com/docs
```

If `ADMIN_ORIGIN` was a guess earlier, update it now to the exact URL Render gave you:

```
Dashboard → Environment → edit ADMIN_ORIGIN → Save (triggers redeploy)
```

---

## Step 6 — CRITICAL: Set up UptimeRobot to prevent cold starts

Render free spins down after 15 min idle. Next request takes ~30s to wake. This will frustrate Flutter devs and break WebSocket testing. Fix it by pinging every 5 min for free.

1. Sign up at https://uptimerobot.com (free, no card)
2. Click **+ Add New Monitor**
3. Fill in:
   - **Monitor Type:** `HTTP(s)`
   - **Friendly Name:** `rideshare-backend-dev`
   - **URL:** `https://rideshare-backend-dev.onrender.com/api/v1/health`
   - **Monitoring Interval:** **5 minutes** (free tier max frequency)
   - **Alert Contacts:** your email
4. Click **Create Monitor**

Now Render thinks your service is always in use → never spins down. Bonus: you also get free uptime monitoring + email if backend goes down.

> **Caveat:** UptimeRobot consumes ~9000 free Render hours/year (~750/month). Render free tier is 750/month per service. You'll be right at the edge but it works — Render measures by clock-on-the-instance, not by request count.

---

## Step 7 — Tell Flutter devs

Send them:

- **Base URL:** `https://rideshare-backend-dev.onrender.com/api/v1`
- **WebSocket:** `wss://rideshare-backend-dev.onrender.com`
- **Swagger:** `https://rideshare-backend-dev.onrender.com/docs`
- **OpenAPI JSON:** `/docs-json` (for dio codegen)
- **Health:** `/api/v1/health`

Mention: first request of the day might be slow (~5–10s) even with UptimeRobot, because Render rebuilds the routing cache. Subsequent requests are fast.

---

## Future deploys

Just `git push origin main`. Render auto-builds + deploys (~5–8 min).

Manual deploy: dashboard → service → **Manual Deploy** → **Deploy latest commit**.

## Updating env vars

```
Dashboard → service → Environment → edit → Save
```

Save triggers automatic redeploy.

## Custom domain (later)

```
Dashboard → service → Settings → Custom Domains → Add
Render gives you a CNAME target → add it to your DNS
Render auto-issues Let's Encrypt TLS
```

---

## Why not Fly / Koyeb / Railway

| Provider   | Free tier in 2026?                            | Card required? |
| ---------- | --------------------------------------------- | -------------- |
| **Render** | ✅ yes                                        | ❌ no          |
| Fly.io     | ❌ trial only — needs card after              | ✅ yes         |
| Koyeb      | ❌ removed — now $30/mo Pro                   | ✅ yes         |
| Railway    | ⚠️ $5 trial credit only                       | ✅ yes         |
| Heroku     | ❌ no free tier                               | ✅ yes         |
| Vercel     | ⚠️ serverless only — not for NestJS+WS+BullMQ | ❌ no          |
| Northflank | ⚠️ free trial only — needs card               | ✅ yes         |

Render is the last meaningful free Docker host without a credit card.

---

## If something goes wrong

| Symptom                              | Fix                                                                    |
| ------------------------------------ | ---------------------------------------------------------------------- |
| Build fails on `pnpm install`        | Check `pnpm-lock.yaml` is committed; Render uses Node 20 by default    |
| `prisma migrate deploy` fails        | Verify `DATABASE_URL`; Supabase free DB may need un-pause              |
| Health check fails                   | Check logs — usually missing env var or DB connection issue            |
| 503 / "Application failed to start"  | OOM — try lighter logging or upgrade. NestJS+Prisma fits in 512MB.     |
| WebSocket disconnects every 5–10 min | Render free idle timeout. UptimeRobot fixes it.                        |
| First request after deploy is slow   | Normal for Render free — image cold-cached. UptimeRobot keeps it warm. |
| CORS errors from admin               | Set `ADMIN_ORIGIN` to exact admin URL (no trailing slash)              |

## Clean up old deploys (optional)

If you don't plan to come back to Fly:

```bash
fly apps destroy rideshare-backend-dev --yes
```

Frees the app name in case you want it later.
