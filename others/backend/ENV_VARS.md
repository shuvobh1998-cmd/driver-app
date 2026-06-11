# Backend Environment Variables

> Every env var the backend reads. If you add one, add it here AND in `backend/.env.example` in the same commit. CI fails if `.env.example` is stale.

## Local (`backend/.env.local`)

```bash
NODE_ENV=development
PORT=3000

# Database (Supabase)
DATABASE_URL=postgresql://...:5432/...?pgbouncer=true&connection_limit=1
DIRECT_URL=postgresql://...:5432/...      # Prisma migrate uses this (bypass pooler)

# Supabase (storage + auth APIs if used)
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Redis (Redis Cloud — NOT Upstash; Upstash free blocks Lua/BullMQ)
REDIS_URL=redis://default:<password>@<host>:<port>

# JWT
JWT_ACCESS_SECRET=<openssl rand -hex 32>
JWT_REFRESH_SECRET=<openssl rand -hex 32>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d

# Firebase (OTP + FCM)
FIREBASE_PROJECT_ID=local-stub
FIREBASE_CLIENT_EMAIL=stub@local-stub.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

# Public base URL (used in invoice PDFs, webhook URLs)
PUBLIC_BASE_URL=http://localhost:3000

# Storage
STORAGE_PROVIDER=local                    # local | cloudinary
STORAGE_LOCAL_ROOT=./uploads
STORAGE_BUCKET_PUBLIC=public
STORAGE_BUCKET_PRIVATE=kyc-docs
CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>   # only if STORAGE_PROVIDER=cloudinary

# KYC encryption
KYC_DOC_NUMBER_KEY=<openssl rand -base64 32>   # base64 of 32 bytes, OR 32-char ASCII string

# CORS (admin origin)
ADMIN_ORIGIN=http://localhost:3001              # must be a valid URL

# Admin seed (used on first migration to create the default admin)
ADMIN_SEED_EMAIL=admin@example.com
ADMIN_SEED_PHONE=+919999999999
ADMIN_SEED_PASSWORD=ChangeMe!2026
ADMIN_SEED_FIRST_NAME=Admin
ADMIN_SEED_LAST_NAME=User

# Razorpay (test mode in dev)
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx
RAZORPAY_WEBHOOK_SECRET=xxx

# Payments (Sprint 8 / Mobile M06)
PAYMENT_PROVIDER=mock                            # mock (dev, HMAC-signs like Razorpay) | razorpay
PLATFORM_COMMISSION_BPS=1000                     # PLACEHOLDER 10% — founder open question #2
PLATFORM_GST_BPS=500                             # PLACEHOLDER 5% on gross fare
PAYOUT_MIN_AMOUNT=10000                          # min withdrawal, paise (₹100)
IDEMPOTENCY_TTL_HOURS=24                         # how long an Idempotency-Key replay is served
INVOICE_COMPANY_NAME=RideShare Technologies Pvt. Ltd.
INVOICE_COMPANY_ADDRESS=Kolkata, West Bengal, India
INVOICE_GSTIN=19AAAAA0000A1Z5

# Sentry (optional in dev)
SENTRY_DSN=

# SMS provider (Mobile M08 — SOS alerts + share links)
SMS_PROVIDER=console                            # console (dev, logs only) | msg91
SMS_SENDER_ID=RIDESH
MSG91_AUTH_KEY=

# Maps (Sprint 3+)
NOMINATIM_USER_AGENT=Mozilla/5.0 (compatible; rideshare/0.1)
OSRM_BASE_URL=https://router.project-osrm.org   # dev free demo
OLA_MAPS_API_KEY=                               # prod only

# Misc
LOG_LEVEL=info                                  # trace | debug | info | warn | error
DEFAULT_CITY=KOLKATA
DEFAULT_CURRENCY=INR
```

## Production (Fly.io secrets)

Set with `fly secrets import < /tmp/fly-secrets.env`. Same keys as above; values differ. Specifically:

- `NODE_ENV=production`
- `PUBLIC_BASE_URL=https://rideshare-backend-dev.fly.dev`
- `STORAGE_PROVIDER=cloudinary` (`local` doesn't survive VM restarts on Fly)
- `ADMIN_ORIGIN=https://rideshare-admin-dev.vercel.app`
- `LOG_LEVEL=info` (or `warn` if too noisy)
- Real Firebase creds (not `local-stub`)
- Real Razorpay keys (test for dev/staging, live for prod)
- Real `SENTRY_DSN`

## Sensitive vs non-sensitive

| Sensitive (NEVER log, NEVER commit)              | Non-sensitive (OK to log / commit example) |
| ------------------------------------------------ | ------------------------------------------ |
| `DATABASE_URL`, `DIRECT_URL`                     | `NODE_ENV`, `PORT`                         |
| `SUPABASE_SERVICE_ROLE_KEY`                      | `SUPABASE_URL`                             |
| `REDIS_URL` (contains password)                  | `STORAGE_PROVIDER`                         |
| `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`        | `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL`        |
| `FIREBASE_PRIVATE_KEY`                           | `FIREBASE_PROJECT_ID`                      |
| `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` | `RAZORPAY_KEY_ID` (still treat carefully)  |
| `CLOUDINARY_URL`                                 | `STORAGE_BUCKET_PUBLIC`                    |
| `KYC_DOC_NUMBER_KEY`                             | `DEFAULT_CITY`                             |
| `ADMIN_SEED_PASSWORD`                            | `ADMIN_SEED_EMAIL`                         |
| `MSG91_AUTH_KEY`                                 | `SMS_PROVIDER`                             |
| `SENTRY_DSN`                                     | `LOG_LEVEL`                                |

## Validation

All env vars are validated at boot via Zod schema in `src/common/env.validation.ts`. **App crashes on startup if any required var is missing or malformed.** This catches misconfig before serving traffic.

## Rotation procedure

When a secret is leaked (chat, screenshot, accidental commit):

1. Generate new value (`openssl rand` for random secrets; gateway dashboard for API keys)
2. Update local `.env.local`
3. `fly secrets set <KEY>="<value>" --app rideshare-backend-dev` (triggers redeploy)
4. If JWT secret rotated → all users get kicked out on next request (expected — they re-login)
5. If Razorpay secret rotated → update webhook URL too if applicable
6. If database password rotated → also update in Supabase dashboard
7. Log the rotation in `docs/AUDIT_LOG.md` (create if doesn't exist)

## Adding a new env var

1. Add to `backend/.env.example` with `=` (no value)
2. Add to Zod schema in `src/common/env.validation.ts`
3. Add to this doc with purpose + sensitivity classification
4. Set in Fly.io via `fly secrets set` for prod
5. Mention in PR description
