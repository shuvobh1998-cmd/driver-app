# Backend Architecture

## Module map (per domain)

Each NestJS module owns its routes, services, queues, and DB models. Cross-module dependencies go through services, never direct DB access.

```
┌──────────────────────────────────────────────────────────────┐
│                       HTTP / WS layer                         │
│                  (Controllers + Gateways)                     │
└──────────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────────┐
│                      Domain services                          │
│  AuthService  UsersService  DriversService  TripsService etc. │
└──────────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────────┐
│                  Infra / shared services                      │
│  PrismaService  RedisService  FirebaseService  RazorpayClient │
│  StorageService  GeocodingProvider  RoutingProvider  Pino     │
└──────────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────────┐
│             Datastores + external                             │
│  Postgres+PostGIS (Supabase)  Redis Cloud  Firebase  Razorpay │
│  Cloudinary  OSRM  Nominatim                                  │
└──────────────────────────────────────────────────────────────┘
```

## Async work — BullMQ queues

| Queue                | Producer                          | Worker              | Purpose                                                             |
| -------------------- | --------------------------------- | ------------------- | ------------------------------------------------------------------- |
| `matching`           | RidesController on request        | MatchingWorker      | Drive nearest-driver matching loop (Sprint 4)                       |
| `notifications`      | NotificationsService              | NotificationsWorker | Send FCM + SMS without blocking request thread                      |
| `payouts`            | PayoutsController on approve      | PayoutsWorker       | Process bank/UPI transfer (manual in MVP, automatable later)        |
| `data-export`        | UsersController on export request | DataExportWorker    | Build user data dump, upload to Cloudinary, email link              |
| `cron` (BullMQ-cron) | n/a                               | various             | Daily cleanups, scheduled-trip status flips, account-deletion sweep |

All queues share the same Redis instance. Job retention: completed 1h, failed 7 days.

## WebSocket layer

- Single Socket.IO server, namespaces: `/rider`, `/driver`, `/admin`
- Auth: JWT in connect query, verified in `WsJwtGuard`
- Rooms: `trip:{tripId}` for per-trip events; `user:{userId}` for direct delivery
- Driver also joins `driver:offers:{vehicleType}` to receive offers
- Outbound throttle for location updates: 1 update/s per trip room (server-side debounce)

## Cross-cutting infrastructure

### `common/`

- `EnvValidationPipe` — Zod schema validates `process.env` on bootstrap; fails fast
- `ErrorEnvelopeFilter` — wraps all errors in the standard `{success, error}` envelope
- `IdempotencyMiddleware` — checks `Idempotency-Key` for money/state POSTs
- `RequestIdMiddleware` — UUID per request, added to logs + error envelope
- Guards: `JwtAuthGuard`, `RolesGuard`, `WsJwtGuard`
- Decorators: `@CurrentUser()`, `@Roles()`, `@Idempotent()`

### `prisma/`

- `PrismaService` extends `PrismaClient` with shutdown hooks
- Connection pooling via Prisma's built-in pool (we set `connection_limit=1` in DATABASE_URL because Supabase pooler manages the real pool)

### `redis/`

- `RedisService` wraps ioredis client
- Helpers: `setIfAbsent(key, val, ttl)` (debounce), `geoAdd/geoSearch`, `acquireLock(key, ttl)`

### `firebase/`

- `FirebaseService` wraps Firebase Admin SDK
- Lazy-loaded (skipped if FIREBASE_PROJECT_ID is `local-stub`)

### `storage/`

- Provider abstraction: `LocalStorageProvider` (dev) and `CloudinaryStorageProvider` (prod)
- Signed URL TTL: 1h for KYC, 7d for vehicle photos, infinite for avatars

### `maps/`

- `GeocodingProvider` interface; impl: `NominatimProvider` (dev, 1.1s rate-limited), future `OlaMapsProvider`
- `RoutingProvider` interface; impl: `OsrmProvider` (dev), future `OlaMapsRoutingProvider`
- All results Redis-cached

## State machines

### Trip

```
REQUESTED → ACCEPTED → ARRIVED → STARTED → ENDED
                ↓         ↓         ↓
           CANCELLED  CANCELLED  CANCELLED
```

Enforced in `TripsService.transitionTo(currentState, nextState, actorRole)` — throws `INVALID_STATE` otherwise.

### Scheduled trip

```
OPEN → FULL (when seats exhausted) → IN_PROGRESS → COMPLETED
  ↓                                       ↓
CANCELLED                             CANCELLED
```

### Booking

```
PENDING (payment held) → CONFIRMED → COMPLETED
              ↓              ↓
         CANCELLED       NO_SHOW
```

## API versioning

- All routes under `/api/v1/...`
- Breaking changes → `/api/v2/...`; `v1` frozen once shipped
- Internal admin routes considered same v1 surface (admin client updates same release cadence as backend)

## Multi-tenancy

- Not in MVP. Single-city (Kolkata).
- Future: add `city_id` column to relevant tables + JWT scoping.

## Observability

- **Logs**: Pino structured JSON to stdout (Fly captures). Request ID in every line.
- **Errors**: Sentry SDK auto-captures unhandled exceptions and 5xx responses. Breadcrumbs include request URL + user ID.
- **Metrics**: not collected in MVP. Future: Prometheus on internal endpoint scraped by Grafana Cloud free tier.
- **Health**: `/api/v1/health` returns DB + Redis + queue status.

## Security

- JWT secrets ≥ 64 hex chars (32 bytes)
- argon2id for admin passwords + user passwords (Sprint 5)
- Phone OTP via Firebase, 6 digits, 5 min TTL
- Rate limiting via `@nestjs/throttler`: 60 req/min IP for public, 300/min user for authed
- Webhook signature verification (Razorpay HMAC SHA256)
- All file uploads scanned for MIME mismatch
- KYC doc numbers encrypted at rest (AES-GCM with `KYC_DOC_NUMBER_KEY`)
- CORS allowlist via `ADMIN_ORIGIN`; tightened in prod
- Helmet via `@fastify/helmet`
- No PII in push payloads, logs, or share-trip pages

## What's deliberately NOT in the architecture

- GraphQL (REST + WS only — Indian app market prefers simple REST)
- gRPC microservices (one monolith is right for MVP team of 1 backend)
- Kafka / RabbitMQ (BullMQ on Redis handles all async work)
- Service mesh
- Custom service discovery
- Kubernetes (Fly.io VMs are simpler)

If we hit > 10k DAU we revisit.
