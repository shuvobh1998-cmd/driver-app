# Backend Test Plan

## Layers

### Unit (`*.service.spec.ts`)

- Pure functions: fare math, OTP hashing, distance calc, polyline decode
- Service methods with mocked repositories
- Validation pipes (Zod / class-validator)
- Run on every PR via Jest

### Integration (`*.controller.spec.ts`)

- Controller + service + Prisma with real test DB (Docker Postgres+PostGIS)
- Run on every PR

### E2E (`test/e2e/*.e2e-spec.ts`)

- Spin up full Nest app + test DB + test Redis
- HTTP via Supertest, WebSocket via socket.io-client
- Cover critical paths per [`TESTING_STRATEGY.md`](TESTING_STRATEGY.md)
- Run on every PR + nightly on `main`

### Load (k6 + Artillery scripts in `test/load/`)

- Run on staging only, before each sprint demo for new features
- Targets: see "Load targets" below

## What to test per module (cumulative across sprints)

### Auth (Sprint 1 + 5)

- OTP send/verify happy + invalid + expired + over-rate
- Signup multi-step (start → verify → complete)
- Login: wrong password locked after 5 attempts/5min
- Refresh token rotation (old token rejected after rotate)
- Logout revokes refresh
- Forgot password resets all sessions

### KYC + Vehicle (Sprint 2)

- File upload size + type validation
- Approve / reject changes status + triggers push
- Doc number encryption round-trip
- Signed URL TTL enforced

### Maps + Fare (Sprint 3)

- Geocode cache hit returns same result without external call
- Fare math: zero distance → min fare; long distance → correct breakdown
- Pricing rule update closes previous + opens new atomically

### Driver state + matching (Sprint 4)

- Online → Redis GEO entry created
- Offline → Redis GEO entry removed
- Location ping debounced (Postgres write only every 5s)
- Stale entry (>90s no ping) auto-removed
- Concurrent accept race: 2 drivers, same offer → exactly 1 wins
- Radius expansion after no acceptance

### Trip lifecycle (Sprint 7)

- State machine forbids invalid transitions (e.g., REQUESTED → ENDED)
- OTP required to start trip
- Location pings persisted at correct rate
- Rating updates denormalized driver `rating_avg` correctly
- Cancellation by rider vs driver records correct `cancelled_by`

### Payments (Sprint 8)

- Razorpay signature verification (positive + negative test vectors)
- Webhook idempotency (replay returns same result, no double-credit)
- Wallet invariant: balance == sum of ledger
- Refund full + partial flows
- Cash trip flow vs UPI trip flow

### Scheduled carpool (Sprint 9)

- Atomic seat booking under concurrent requests
- Corridor search returns matches and excludes off-route trips
- Cancellation refund per policy tier
- Departure cron auto-flips status

### Notifications + Support (Sprint 10)

- FCM unregister cleanup on stale tokens
- Push payloads contain `type` for deep-link
- Support ticket assignment + reply round-trip

## Test DB strategy

- Docker Compose: `postgis/postgis:15-3.4` + `redis:7-alpine`
- Each test suite runs migrations + truncates between tests (NOT drop/recreate — too slow)
- Use a single test DB per Jest worker; isolate via SAVEPOINT or schema-per-worker
- Seed minimal fixtures per suite

## Load targets

| Endpoint                    | Target                                                  |
| --------------------------- | ------------------------------------------------------- |
| `GET /health`               | 5000 rps p95 < 50ms                                     |
| `POST /auth/login`          | 200 rps p95 < 300ms                                     |
| `POST /drivers/me/location` | 1000 rps p95 < 100ms (Redis only)                       |
| `POST /rides/request`       | 100 rps p95 < 500ms                                     |
| WS broadcast                | 200 concurrent connections, message fan-out p95 < 200ms |

If these fail on Fly shared-cpu-1x → upgrade VM before launch.

## CI workflow snippet

`.github/workflows/backend-test.yml`:

```yaml
name: Backend test
on: [pull_request, push]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:15-3.4
        env: { POSTGRES_PASSWORD: postgres }
        ports: ['5432:5432']
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: cd backend && pnpm prisma migrate deploy
      - run: cd backend && pnpm lint
      - run: cd backend && pnpm typecheck
      - run: cd backend && pnpm test
      - run: cd backend && pnpm test:e2e
```
