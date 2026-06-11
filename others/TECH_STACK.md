# Tech Stack

Every choice here is locked unless a specific blocker forces a change. If you change one, update this doc _and_ note the reason in the sprint doc where the change happened.

## Backend

| Concern      | Choice                                      | Why                                                                                                                                                                                           |
| ------------ | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Framework    | **NestJS 11**                               | Strong module system, DI, decorators, mature ecosystem; v11 uses Express 5 internals + stricter types                                                                                         |
| HTTP adapter | **Fastify**                                 | ~2× throughput vs Express, lower latency, schema validation                                                                                                                                   |
| Language     | **TypeScript** (strict mode)                | Type safety, catches bugs early                                                                                                                                                               |
| ORM          | **Prisma 6** (latest stable)                | Type-safe, great DX, easy migrations. **Not Prisma 7** — v7 (Jan 2026) requires `prisma.config.ts` + driver adapters; ecosystem and NestJS tutorials still catching up. Revisit in Sprint 7+. |
| Validation   | **class-validator + class-transformer**     | Native NestJS pattern                                                                                                                                                                         |
| API docs     | **Swagger / OpenAPI** (`@nestjs/swagger`)   | Auto-generated from decorators; mockable for Flutter devs                                                                                                                                     |
| Logging      | **Pino**                                    | Fastest Node logger; structured JSON for prod                                                                                                                                                 |
| Config       | **@nestjs/config** + Zod for env validation | Fails fast on missing env vars                                                                                                                                                                |
| Testing      | **Jest** (unit) + **Supertest** (e2e)       | Standard NestJS combo                                                                                                                                                                         |

## Database

| Concern        | Choice                       | Why                                                 |
| -------------- | ---------------------------- | --------------------------------------------------- |
| Primary DB     | **PostgreSQL 15+**           | Battle-tested, JSON support, strong consistency     |
| Geo extension  | **PostGIS**                  | `ST_DWithin`, `ST_Distance`, route corridor queries |
| Hosting (dev)  | **Supabase free tier**       | Postgres + PostGIS + Storage + Auth in one          |
| Hosting (prod) | **Supabase Pro** or **Neon** | When dev limits are hit                             |
| Migrations     | **Prisma Migrate**           | Checked into git, applied in CI                     |

## Cache + Realtime infra

| Concern             | Choice                                         | Why                                         |
| ------------------- | ---------------------------------------------- | ------------------------------------------- |
| Cache               | **Redis**                                      | Standard for sessions, rate limits          |
| Driver location geo | **Redis GEO commands** (`GEOADD`, `GEOSEARCH`) | Sub-ms lookups vs PostGIS for hot path      |
| Hosting (dev)       | **Upstash free tier**                          | 10k commands/day, REST-compatible           |
| WebSockets          | **Socket.IO**                                  | Rooms, auto-reconnect, broad client support |
| Job queue           | **BullMQ** (Redis-backed)                      | Notifications, async payments, payouts      |

## Auth & Identity

| Concern        | Choice                           | Why                                |
| -------------- | -------------------------------- | ---------------------------------- |
| Phone OTP      | **Firebase Auth**                | Free up to 10k verifications/month |
| Session tokens | **JWT** (access + refresh)       | Stateless, scales horizontally     |
| Hashing        | **argon2** (for admin passwords) | Modern, memory-hard                |

## Payments

| Concern         | Choice                                      | Why                                    |
| --------------- | ------------------------------------------- | -------------------------------------- |
| Gateway         | **Razorpay**                                | UPI, cards, wallets; standard in India |
| Test mode       | Free                                        | Use throughout dev                     |
| Webhook signing | **HMAC SHA256 (Razorpay-Signature header)** | Standard pattern                       |

## Maps / Geo

| Concern           | Dev choice                                                | Prod choice                           |
| ----------------- | --------------------------------------------------------- | ------------------------------------- |
| Map tiles         | **OpenStreetMap**                                         | Mapbox or OLA Maps                    |
| Geocoding         | **Nominatim** (1 req/sec limit)                           | OLA Maps or Google Geocoding          |
| Routing           | **OSRM** (public demo) or **Mapbox Directions** free tier | OLA Maps Routing or Google Directions |
| Reverse geocoding | Nominatim                                                 | OLA Maps or Google                    |

> **Why OLA Maps for prod over Google:** ~70% cheaper for Indian usage, Indian address quality is comparable, INR billing.

## Storage

| Concern                         | Choice                                           | Why                                      |
| ------------------------------- | ------------------------------------------------ | ---------------------------------------- |
| User docs (KYC), vehicle photos | **Supabase Storage** free or **Cloudinary** free | 1GB+ free; signed URLs; image transforms |
| File size limits                | 5MB per upload                                   | Enforced server-side                     |

## Notifications

| Concern             | Choice                       | Why                                         |
| ------------------- | ---------------------------- | ------------------------------------------- |
| Push (Android/iOS)  | **Firebase Cloud Messaging** | Free, multi-platform                        |
| SMS (critical only) | **MSG91** or **Fast2SMS**    | Razorpay alternatives; Indian DLT-compliant |
| Email (admin only)  | **Resend** free tier         | 3k emails/mo                                |

## Admin Panel

| Concern       | Choice                                  | Why                                                                        |
| ------------- | --------------------------------------- | -------------------------------------------------------------------------- |
| Framework     | **Next.js 15** App Router (React 19)    | SSR, easy auth, fast dev; async request APIs, Turbopack stable             |
| UI library    | **shadcn** (new CLI, Tailwind v4–ready) | Copy-paste components, owned code, Tailwind-native                         |
| Styling       | **Tailwind CSS v4**                     | CSS-first config (`@theme`), Lightning-CSS engine, no `tailwind.config.js` |
| Data fetching | **TanStack Query**                      | Cache, refetch, optimistic updates                                         |
| Forms         | **react-hook-form + Zod**               | Type-safe, performant                                                      |
| Maps in admin | **Leaflet + OSM tiles**                 | Free, simple                                                               |
| Charts        | **Recharts**                            | Simple, declarative                                                        |

## Hosting

| Layer          | Dev                             | Prod (when paid)          |
| -------------- | ------------------------------- | ------------------------- |
| Backend API    | **Railway** ($5 free credit/mo) | Railway Pro / AWS Fargate |
| Admin panel    | **Vercel free tier**            | Vercel Pro                |
| Database       | **Supabase free**               | Supabase Pro              |
| Redis          | **Upstash free**                | Upstash paid              |
| Object storage | **Supabase Storage free**       | Cloudflare R2 or S3       |
| CDN            | Vercel built-in                 | Cloudflare                |

## Observability

| Concern     | Choice                                           |
| ----------- | ------------------------------------------------ |
| Errors      | **Sentry** free tier (5k events/mo)              |
| Logs        | Railway/Vercel built-in + Pino structured        |
| Uptime      | **UptimeRobot** free (50 monitors)               |
| API metrics | Built-in NestJS interceptor → Sentry breadcrumbs |

## CI/CD

| Concern            | Choice                                           |
| ------------------ | ------------------------------------------------ |
| CI                 | **GitHub Actions**                               |
| Tests on PR        | unit + e2e + lint + type-check                   |
| Auto-deploy `main` | Railway (backend), Vercel (admin)                |
| Secrets            | GitHub Actions secrets + Railway/Vercel env vars |

## Local dev

- **Node.js:** 22.x LTS (required by NestJS 11)
- **pnpm 10** package manager (faster than npm, disk-efficient; workspace catalog support)
- **Docker Compose** for local Postgres+PostGIS + Redis when offline
- **direnv** or `.env.local` for local secrets
