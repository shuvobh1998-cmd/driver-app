# Backend (NestJS + Fastify)

This folder = backend-specific reference docs.

## Read these

| File                                 | Purpose                                               |
| ------------------------------------ | ----------------------------------------------------- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Module map, services, queues, layering                |
| [`ENV_VARS.md`](ENV_VARS.md)         | Every env var catalogued (purpose, where set, sample) |
| [`../sprints/`](../sprints/)         | Per-sprint backend feature plans                      |

## Stack reminder

- NestJS 11 + Fastify
- TypeScript strict
- Prisma + PostgreSQL + PostGIS (Supabase)
- Redis (Redis Cloud — NOT Upstash, which blocks Lua/BullMQ)
- Socket.IO
- BullMQ for queues
- Firebase Admin for OTP + FCM
- Razorpay SDK
- Cloudinary SDK
- Sentry

## Repo layout

```
backend/
├── src/
│   ├── auth/                 # OTP, password, JWT, refresh tokens
│   ├── users/                # profile, addresses, preferences, sessions
│   ├── drivers/              # driver profile, kyc, vehicles, state, geo, earnings
│   ├── admin/                # all admin endpoints
│   ├── maps/                 # geocoding, routing, providers
│   ├── fares/                # pricing rules, fare engine
│   ├── rides/                # ride requests
│   ├── matching/             # BullMQ worker, geo pool
│   ├── trips/                # trip lifecycle, location pings, ratings
│   ├── payments/             # razorpay, webhooks, wallet, payouts, invoices
│   ├── scheduled/            # carpool trips + bookings
│   ├── chats/                # chat threads + messages
│   ├── notifications/        # FCM + SMS + in-app + templates
│   ├── safety/               # SOS, trip shares
│   ├── support/              # tickets, lost items
│   ├── content/              # CMS (FAQ / articles / legal)
│   ├── app-config/           # app config endpoint
│   ├── webhooks/             # external webhooks (razorpay)
│   ├── ws/                   # socket.io gateways
│   ├── common/               # shared (env validation, error envelope, idempotency, guards)
│   ├── prisma/               # PrismaService
│   ├── redis/                # RedisService wrapper
│   └── main.ts               # bootstrap + Swagger + Pino
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── test/
│   ├── unit/
│   └── e2e/
├── scripts/
│   ├── dev-token.ts          # generate dev JWT
│   └── *.ts
├── Dockerfile (lives at repo root for monorepo)
├── package.json
└── .env.example
```

## Run locally

```bash
cd backend
cp .env.example .env.local   # fill in
pnpm install
pnpm prisma generate
pnpm prisma migrate dev
pnpm db:seed
pnpm dev
```

API at `http://localhost:3000/api/v1`, Swagger at `http://localhost:3000/docs`.

## Deploy

See [`../FREE_TIER_GUIDE.md`](../FREE_TIER_GUIDE.md) for Fly.io setup. Build / runtime via root `Dockerfile`.
