# API Conventions

> Locked. Every endpoint must follow these. Document deviations explicitly.

## Base URL & versioning

- **Dev:** `https://rideshare-api.up.railway.app/api/v1`
- **Prod:** `https://api.<domain>/api/v1`

Version is in the URL (`/api/v1`). Breaking changes go to `/api/v2`. Never break `v1` once published.

## Authentication

- **JWT Bearer token** in `Authorization` header: `Authorization: Bearer <access_token>`
- **Access token** TTL: 15 minutes
- **Refresh token** TTL: 30 days (rotated on use)
- Refresh endpoint: `POST /api/v1/auth/refresh` (refresh token in body, not header)

### Roles
- `RIDER` — user booking rides
- `DRIVER` — driver offering rides
- `ADMIN` — admin panel user
- `SUPPORT` — limited admin (read-only + ticket actions)

Endpoints declare required role(s) via guard. Mixed-role endpoints document explicitly.

## Request format

- **JSON only.** `Content-Type: application/json` for all bodies.
- File uploads use `multipart/form-data` (KYC docs, vehicle photos).
- Query params for filters and pagination, body for state changes.
- All timestamps in **ISO 8601 UTC** (`2026-05-23T12:34:56.789Z`).
- All money in **integer paise** (₹100 = `10000`). Never use floats for money.
- Distances in **meters**. Durations in **seconds**.
- Geo points in `{ "lat": 22.5726, "lng": 88.3639 }`. Never `[lng, lat]` in API responses (GeoJSON convention reserved for internal use).

## Response envelopes

### Success

```json
{
  "success": true,
  "data": { ... },
  "meta": { "requestId": "req_abc123", "timestamp": "2026-05-23T12:34:56Z" }
}
```

### List / pagination

```json
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 153,
    "hasMore": true
  },
  "meta": { "requestId": "req_abc123", "timestamp": "..." }
}
```

### Error

```json
{
  "success": false,
  "error": {
    "code": "DRIVER_NOT_AVAILABLE",
    "message": "No drivers available within 3km radius",
    "details": { ... },
    "field": null
  },
  "meta": { "requestId": "req_abc123", "timestamp": "..." }
}
```

- `code` is a stable, UPPER_SNAKE_CASE string. Mobile/admin clients switch on `code`, not `message`.
- `message` is human-readable English. Localization is out of scope for MVP.
- `field` is set for validation errors (e.g., `"phone"`).
- `details` is optional structured info (e.g., validation errors per field).

## HTTP status codes

| Code | When |
|---|---|
| 200 | Successful GET/PUT/PATCH/DELETE |
| 201 | Successful POST that created a resource |
| 204 | Successful DELETE with no body |
| 400 | Client error — validation, malformed request |
| 401 | Missing or invalid auth token |
| 403 | Authenticated but not authorized (role/ownership) |
| 404 | Resource not found |
| 409 | Conflict — duplicate, state machine violation |
| 422 | Semantic validation failed (e.g., trip cannot be cancelled in current state) |
| 429 | Rate limited |
| 500 | Server error — unhandled |
| 503 | Dependency down (DB, payment gateway) |

## Pagination

- `?page=1&pageSize=20` (default `pageSize=20`, max `100`)
- Cursor pagination for high-volume lists (trips, location pings): `?cursor=<opaque>&limit=50`

## Filtering & sorting

- Filters: `?status=ACTIVE&vehicleType=AUTO`
- Sorting: `?sort=createdAt&order=desc` (single column for MVP)
- Date range: `?from=2026-01-01&to=2026-01-31` (UTC, inclusive)

## Idempotency

- All POSTs that create money movement or trip state changes require `Idempotency-Key` header.
- Server stores key → response for 24h; replay returns the cached response.

## Rate limiting

- Per-IP: 60 req/min on public endpoints (`/auth/*`)
- Per-user: 300 req/min on authenticated endpoints
- Per-driver location ping: 1/2s (handled at WebSocket layer, not REST)
- Exceeded → `429` with `Retry-After` header

## Standard error codes

| Code | HTTP | Meaning |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Body/query failed validation |
| `UNAUTHENTICATED` | 401 | Missing/invalid token |
| `TOKEN_EXPIRED` | 401 | Access token expired (use refresh) |
| `FORBIDDEN` | 403 | Authenticated but wrong role |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `DUPLICATE` | 409 | Unique constraint violated |
| `INVALID_STATE` | 422 | State machine transition not allowed |
| `RATE_LIMITED` | 429 | Slow down |
| `INTERNAL_ERROR` | 500 | Server bug |
| `SERVICE_UNAVAILABLE` | 503 | Dependency down |

Domain-specific codes (added per sprint):
- `OTP_INVALID`, `OTP_EXPIRED`
- `DRIVER_NOT_AVAILABLE`, `DRIVER_OFFLINE`
- `TRIP_ALREADY_ACCEPTED`, `TRIP_NOT_CANCELABLE`
- `INSUFFICIENT_SEATS`, `TRIP_FULL`
- `PAYMENT_FAILED`, `PAYMENT_REQUIRED`
- `KYC_INCOMPLETE`, `KYC_REJECTED`

## Naming

- URL paths: kebab-case, plural nouns (`/scheduled-trips`, `/drivers/:id/documents`)
- Query params: camelCase (`vehicleType`, `pageSize`)
- JSON keys: camelCase (`firstName`, `createdAt`)
- IDs: prefixed string identifiers — `usr_abc123`, `drv_xyz789`, `trp_def456`, `pay_ghi789`
  - Generated via `nanoid(12)` with prefix. Never expose raw DB integer PKs.

## Webhooks (Razorpay etc.)

- Path: `/api/v1/webhooks/<provider>` (e.g., `/api/v1/webhooks/razorpay`)
- Always verify signature before processing
- Always idempotent — webhook may fire twice
- Return 200 immediately, do work async (BullMQ)

## WebSockets

- Single endpoint: `wss://<host>/ws`
- Auth: JWT in connection query `?token=<jwt>`
- Namespaces: `/rider`, `/driver`, `/admin`
- Events follow `noun.verb` pattern: `driver.location.updated`, `trip.status.changed`
- See [DB_SCHEMA.md](DB_SCHEMA.md) for trip state values

## Swagger / OpenAPI

- Live at `/docs` on every environment
- Generated from controller decorators
- Postman collection exported per sprint and committed to `docs/postman/`
