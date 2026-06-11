# Database Schema

> Source of truth = Prisma schema (`backend/prisma/schema.prisma`). This doc explains intent, decisions, and PostGIS specifics. Update this when migrations are added.

## Extensions

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- for fuzzy name search in admin
```

## Conventions

- Primary key: `id BIGSERIAL` internally, plus `public_id VARCHAR(20) UNIQUE` (e.g., `usr_abc123def456`) exposed via API.
- Timestamps: `created_at`, `updated_at`, `deleted_at` (soft delete) on every business table.
- Soft delete only for user-facing entities (users, drivers, trips). Audit/ledger tables are append-only.
- Money: `BIGINT` paise.
- Geo: `geography(Point, 4326)` for points; index with GIST.
- Enums via Prisma enums → Postgres `CHECK` constraints.

## Tables overview (by sprint)

### Sprint 1 — Foundation

#### `users`

General person record (could be rider, driver, both, or admin).

| Column                             | Type                                  | Notes                                      |
| ---------------------------------- | ------------------------------------- | ------------------------------------------ |
| id                                 | BIGSERIAL PK                          |                                            |
| public_id                          | VARCHAR(20) UNIQUE                    | `usr_*`                                    |
| phone                              | VARCHAR(15) UNIQUE NOT NULL           | E.164 format                               |
| email                              | VARCHAR(255) NULL UNIQUE              | optional                                   |
| first_name                         | VARCHAR(100)                          |                                            |
| last_name                          | VARCHAR(100)                          |                                            |
| password_hash                      | VARCHAR(255) NULL                     | argon2id, only set for ADMIN/SUPPORT       |
| roles                              | UserRole[] NOT NULL DEFAULT '{RIDER}' | enum array — RIDER, DRIVER, ADMIN, SUPPORT |
| status                             | UserStatus NOT NULL DEFAULT 'ACTIVE'  | ACTIVE, SUSPENDED, BANNED, DELETED         |
| firebase_uid                       | VARCHAR(128) UNIQUE                   | from Firebase Auth                         |
| created_at, updated_at, deleted_at | TIMESTAMPTZ                           |                                            |

Indexes: `phone` (unique), `email` (unique), `firebase_uid` (unique + btree).

> **Note on `password_hash`:** riders and drivers authenticate via Firebase phone OTP and have `password_hash = NULL`. Admin/support users authenticate with email + argon2id-hashed password. Sprint 1 seed script (`prisma/seed.ts`) creates the first admin row.
>
> **Note on `roles`:** implemented as a Postgres enum array (`UserRole[]`) rather than `TEXT[]` so Prisma can enforce values at the type level. Same set of allowed values: RIDER, DRIVER, ADMIN, SUPPORT.

#### `auth_refresh_tokens`

| Column      | Type                  | Notes                   |
| ----------- | --------------------- | ----------------------- |
| id          | BIGSERIAL PK          |                         |
| user_id     | BIGINT FK users       |                         |
| token_hash  | VARCHAR(128) NOT NULL | SHA256 of refresh token |
| expires_at  | TIMESTAMPTZ NOT NULL  |                         |
| revoked_at  | TIMESTAMPTZ           | NULL = active           |
| device_info | JSONB                 | UA, model, OS           |
| created_at  | TIMESTAMPTZ           |                         |

### Sprint 2 — Profiles & KYC

#### `driver_profiles`

| Column                  | Type                          | Notes                                  |
| ----------------------- | ----------------------------- | -------------------------------------- |
| user_id                 | BIGINT PK FK users            | one-to-one                             |
| date_of_birth           | DATE                          |                                        |
| gender                  | VARCHAR(10)                   |                                        |
| emergency_contact_name  | VARCHAR(100)                  |                                        |
| emergency_contact_phone | VARCHAR(15)                   |                                        |
| kyc_status              | VARCHAR(20) DEFAULT 'PENDING' | PENDING, IN_REVIEW, APPROVED, REJECTED |
| kyc_rejected_reason     | TEXT                          |                                        |
| approved_at             | TIMESTAMPTZ                   |                                        |
| approved_by_user_id     | BIGINT FK users               | admin who approved                     |
| total_trips             | INT DEFAULT 0                 | denormalized counter                   |
| rating_avg              | NUMERIC(3,2) DEFAULT 0        | denormalized                           |
| rating_count            | INT DEFAULT 0                 |                                        |

#### `kyc_documents`

| Column      | Type                 | Notes                                   |
| ----------- | -------------------- | --------------------------------------- |
| id          | BIGSERIAL PK         |                                         |
| user_id     | BIGINT FK users      |                                         |
| doc_type    | VARCHAR(20) NOT NULL | AADHAAR, DL, PAN, RC, INSURANCE, PERMIT |
| doc_number  | VARCHAR(50)          | encrypted at rest                       |
| file_url    | TEXT NOT NULL        | signed storage URL                      |
| verified    | BOOL DEFAULT FALSE   |                                         |
| verified_at | TIMESTAMPTZ          |                                         |
| expires_at  | DATE                 | DL/insurance expiry                     |
| uploaded_at | TIMESTAMPTZ          |                                         |

#### `vehicles`

| Column              | Type                                   | Notes                              |
| ------------------- | -------------------------------------- | ---------------------------------- |
| id                  | BIGSERIAL PK                           |                                    |
| public_id           | VARCHAR(20) UNIQUE                     | `veh_*`                            |
| owner_user_id       | BIGINT FK users                        | driver                             |
| vehicle_type        | VARCHAR(10) NOT NULL                   | BIKE, AUTO, CNG, CAR               |
| make                | VARCHAR(50)                            |                                    |
| model               | VARCHAR(50)                            |                                    |
| year                | INT                                    |                                    |
| color               | VARCHAR(30)                            |                                    |
| registration_number | VARCHAR(20) UNIQUE NOT NULL            |                                    |
| seat_count          | INT NOT NULL                           | for carpool seat math              |
| photo_url           | TEXT                                   |                                    |
| status              | VARCHAR(20) DEFAULT 'PENDING_APPROVAL' | PENDING_APPROVAL, ACTIVE, INACTIVE |
| approved_at         | TIMESTAMPTZ                            |                                    |

### Sprint 3 — Maps & Fare

#### `saved_addresses`

| Column       | Type                            | Notes              |
| ------------ | ------------------------------- | ------------------ |
| id           | BIGSERIAL PK                    |                    |
| user_id      | BIGINT FK users                 |                    |
| label        | VARCHAR(50)                     | HOME, WORK, custom |
| address_text | TEXT NOT NULL                   |                    |
| location     | geography(Point, 4326) NOT NULL |                    |
| created_at   | TIMESTAMPTZ                     |                    |
| updated_at   | TIMESTAMPTZ                     | PATCH bumps this   |

Index: GIST on `location`, btree on `user_id`.

> **PostGIS + Prisma:** `location` is typed `Unsupported("geography(Point, 4326)")`
> in the schema, so the Prisma Client can't read or write it. `AddressesService`
> uses raw SQL — `ST_MakePoint(lng, lat)` on write, `ST_X`/`ST_Y` on read. The
> GIST index lives in the migration only (Prisma can't index Unsupported columns).
> Hard delete (no `deleted_at`): an address-book entry is disposable.

#### `pricing_rules`

| Column           | Type                                   | Notes     |
| ---------------- | -------------------------------------- | --------- |
| id               | BIGSERIAL PK                           |           |
| vehicle_type     | VARCHAR(10) NOT NULL                   |           |
| city             | VARCHAR(50) NOT NULL DEFAULT 'KOLKATA' |           |
| base_fare        | INT NOT NULL                           | paise     |
| per_km           | INT NOT NULL                           | paise/km  |
| per_minute       | INT NOT NULL                           | paise/min |
| minimum_fare     | INT NOT NULL                           | paise     |
| platform_fee_pct | NUMERIC(5,2) DEFAULT 10                |           |
| gst_pct          | NUMERIC(5,2) DEFAULT 5                 |           |
| effective_from   | TIMESTAMPTZ NOT NULL                   |           |
| effective_to     | TIMESTAMPTZ                            |           |

Unique (`vehicle_type`, `city`, `effective_from`).

### Sprint 4 — On-demand Matching

#### `driver_states`

Hot table — denormalized current state. One row per driver.

| Column              | Type                          | Notes                           |
| ------------------- | ----------------------------- | ------------------------------- |
| user_id             | BIGINT PK FK users            |                                 |
| current_vehicle_id  | BIGINT FK vehicles            | active vehicle                  |
| status              | VARCHAR(20) DEFAULT 'OFFLINE' | OFFLINE, ONLINE, ON_TRIP, BREAK |
| current_location    | geography(Point, 4326)        | last known                      |
| location_updated_at | TIMESTAMPTZ                   |                                 |
| current_trip_id     | BIGINT FK trips               | NULL if not on trip             |
| went_online_at      | TIMESTAMPTZ                   |                                 |

> **Note:** Live driver positions also live in Redis GEO key `drivers:live:<vehicleType>` for fast nearest-driver queries. Postgres is durability + admin map; Redis is the hot path.

#### `ride_requests`

| Column             | Type                            | Notes                                  |
| ------------------ | ------------------------------- | -------------------------------------- |
| id                 | BIGSERIAL PK                    |                                        |
| public_id          | VARCHAR(20) UNIQUE              | `req_*`                                |
| rider_user_id      | BIGINT FK users                 |                                        |
| pickup_location    | geography(Point, 4326) NOT NULL |                                        |
| pickup_address     | TEXT                            |                                        |
| drop_location      | geography(Point, 4326) NOT NULL |                                        |
| drop_address       | TEXT                            |                                        |
| vehicle_type       | VARCHAR(10) NOT NULL            |                                        |
| estimated_fare     | INT NOT NULL                    | paise                                  |
| estimated_distance | INT NOT NULL                    | meters                                 |
| estimated_duration | INT NOT NULL                    | seconds                                |
| status             | VARCHAR(20) DEFAULT 'PENDING'   | PENDING, MATCHED, NO_DRIVER, CANCELLED |
| matched_trip_id    | BIGINT FK trips                 |                                        |
| created_at         | TIMESTAMPTZ                     |                                        |

### Sprint 7 — Trips

#### `trips`

| Column                                        | Type                          | Notes                                           |
| --------------------------------------------- | ----------------------------- | ----------------------------------------------- |
| id                                            | BIGSERIAL PK                  |                                                 |
| public_id                                     | VARCHAR(20) UNIQUE            | `trp_*`                                         |
| ride_request_id                               | BIGINT FK ride_requests       | NULL for scheduled trips                        |
| scheduled_trip_id                             | BIGINT FK scheduled_trips     | NULL for on-demand                              |
| rider_user_id                                 | BIGINT FK users               |                                                 |
| driver_user_id                                | BIGINT FK users               |                                                 |
| vehicle_id                                    | BIGINT FK vehicles            |                                                 |
| vehicle_type                                  | VARCHAR(10) NOT NULL          |                                                 |
| pickup_location                               | geography(Point, 4326)        |                                                 |
| drop_location                                 | geography(Point, 4326)        |                                                 |
| status                                        | VARCHAR(20) NOT NULL          | see state machine below                         |
| accepted_at, arrived_at, started_at, ended_at | TIMESTAMPTZ                   |                                                 |
| cancelled_at                                  | TIMESTAMPTZ                   |                                                 |
| cancelled_by                                  | VARCHAR(20)                   | RIDER, DRIVER, SYSTEM, ADMIN                    |
| cancel_reason                                 | TEXT                          |                                                 |
| actual_distance                               | INT                           | meters                                          |
| actual_duration                               | INT                           | seconds                                         |
| fare_breakdown                                | JSONB                         | base, per_km, per_min, platform_fee, gst, total |
| total_fare                                    | INT                           | paise                                           |
| payment_status                                | VARCHAR(20) DEFAULT 'PENDING' | PENDING, PAID, FAILED, REFUNDED                 |
| rider_rating                                  | INT                           | 1-5                                             |
| driver_rating                                 | INT                           | 1-5                                             |

**Trip state machine:**

```
REQUESTED → ACCEPTED → ARRIVED → STARTED → ENDED
                ↓         ↓         ↓
           CANCELLED  CANCELLED  CANCELLED  (terminal)
```

#### `trip_location_pings`

Append-only stream of driver GPS during a trip.

| Column      | Type                            | Notes    |
| ----------- | ------------------------------- | -------- |
| id          | BIGSERIAL PK                    |          |
| trip_id     | BIGINT FK trips                 |          |
| location    | geography(Point, 4326) NOT NULL |          |
| recorded_at | TIMESTAMPTZ NOT NULL            |          |
| speed_mps   | NUMERIC(5,2)                    | optional |
| bearing     | NUMERIC(5,2)                    | optional |

Partition by month if volume grows.

### Sprint 8 — Payments

#### `payments`

| Column             | Type                          | Notes                              |
| ------------------ | ----------------------------- | ---------------------------------- |
| id                 | BIGSERIAL PK                  |                                    |
| public_id          | VARCHAR(20) UNIQUE            | `pay_*`                            |
| trip_id            | BIGINT FK trips               |                                    |
| user_id            | BIGINT FK users               | rider                              |
| amount             | INT NOT NULL                  | paise                              |
| currency           | VARCHAR(3) DEFAULT 'INR'      |                                    |
| method             | VARCHAR(20)                   | CASH, UPI, CARD, WALLET            |
| status             | VARCHAR(20) DEFAULT 'PENDING' | PENDING, SUCCESS, FAILED, REFUNDED |
| gateway            | VARCHAR(20)                   | RAZORPAY, MANUAL                   |
| gateway_order_id   | VARCHAR(64)                   |                                    |
| gateway_payment_id | VARCHAR(64)                   |                                    |
| failure_reason     | TEXT                          |                                    |
| idempotency_key    | VARCHAR(64) UNIQUE            |                                    |
| created_at         | TIMESTAMPTZ                   |                                    |

#### `wallet_accounts`

| Column     | Type                      | Notes               |
| ---------- | ------------------------- | ------------------- |
| user_id    | BIGINT PK FK users        | one wallet per user |
| balance    | BIGINT NOT NULL DEFAULT 0 | paise               |
| updated_at | TIMESTAMPTZ               |                     |

#### `wallet_ledger`

Append-only ledger.

| Column        | Type                 | Notes                                           |
| ------------- | -------------------- | ----------------------------------------------- |
| id            | BIGSERIAL PK         |                                                 |
| user_id       | BIGINT FK users      |                                                 |
| type          | VARCHAR(20) NOT NULL | CREDIT, DEBIT                                   |
| amount        | BIGINT NOT NULL      | always positive; type indicates direction       |
| balance_after | BIGINT NOT NULL      | running balance                                 |
| reason        | VARCHAR(50)          | TRIP_EARNING, PAYOUT, BONUS, REFUND, ADJUSTMENT |
| reference_id  | VARCHAR(20)          | trip public_id, payout id                       |
| notes         | TEXT                 |                                                 |
| created_at    | TIMESTAMPTZ          |                                                 |

#### `payouts`

| Column             | Type                          | Notes                             |
| ------------------ | ----------------------------- | --------------------------------- |
| id                 | BIGSERIAL PK                  |                                   |
| public_id          | VARCHAR(20) UNIQUE            | `pyt_*`                           |
| user_id            | BIGINT FK users               |                                   |
| amount             | BIGINT NOT NULL               | paise                             |
| status             | VARCHAR(20) DEFAULT 'PENDING' | PENDING, PROCESSING, PAID, FAILED |
| method             | VARCHAR(20)                   | BANK_TRANSFER, UPI                |
| upi_id             | VARCHAR(64)                   | if UPI                            |
| bank_account_last4 | VARCHAR(4)                    |                                   |
| processed_at       | TIMESTAMPTZ                   |                                   |
| reference_number   | VARCHAR(64)                   | bank UTR                          |

### Sprint 9 — Scheduled carpool

#### `scheduled_trips`

| Column               | Type                            | Notes                                           |
| -------------------- | ------------------------------- | ----------------------------------------------- |
| id                   | BIGSERIAL PK                    |                                                 |
| public_id            | VARCHAR(20) UNIQUE              | `sch_*`                                         |
| driver_user_id       | BIGINT FK users                 |                                                 |
| vehicle_id           | BIGINT FK vehicles              |                                                 |
| origin_location      | geography(Point, 4326) NOT NULL |                                                 |
| origin_address       | TEXT                            |                                                 |
| destination_location | geography(Point, 4326) NOT NULL |                                                 |
| destination_address  | TEXT                            |                                                 |
| route_line           | geography(LineString, 4326)     | polyline of planned route (for corridor search) |
| departure_at         | TIMESTAMPTZ NOT NULL            |                                                 |
| total_seats          | INT NOT NULL                    |                                                 |
| available_seats      | INT NOT NULL                    | denormalized                                    |
| price_per_seat       | INT NOT NULL                    | paise                                           |
| notes                | TEXT                            | optional driver note                            |
| status               | VARCHAR(20) DEFAULT 'OPEN'      | OPEN, FULL, IN_PROGRESS, COMPLETED, CANCELLED   |
| cancellation_policy  | VARCHAR(20) DEFAULT 'STANDARD'  |                                                 |
| created_at           | TIMESTAMPTZ                     |                                                 |

Index: GIST on `route_line` for `ST_DWithin` corridor queries.

#### `seat_bookings`

| Column            | Type                            | Notes                                             |
| ----------------- | ------------------------------- | ------------------------------------------------- |
| id                | BIGSERIAL PK                    |                                                   |
| public_id         | VARCHAR(20) UNIQUE              | `bkg_*`                                           |
| scheduled_trip_id | BIGINT FK scheduled_trips       |                                                   |
| rider_user_id     | BIGINT FK users                 |                                                   |
| seats_booked      | INT NOT NULL DEFAULT 1          |                                                   |
| pickup_location   | geography(Point, 4326) NOT NULL | rider's pickup along route                        |
| drop_location     | geography(Point, 4326) NOT NULL |                                                   |
| price_paid        | INT NOT NULL                    | paise                                             |
| payment_id        | BIGINT FK payments              |                                                   |
| status            | VARCHAR(20) DEFAULT 'PENDING'   | PENDING, CONFIRMED, CANCELLED, COMPLETED, NO_SHOW |
| created_at        | TIMESTAMPTZ                     |                                                   |

#### `chat_messages`

| Column            | Type                      | Notes             |
| ----------------- | ------------------------- | ----------------- |
| id                | BIGSERIAL PK              |                   |
| trip_id           | BIGINT FK trips           | NULL if scheduled |
| scheduled_trip_id | BIGINT FK scheduled_trips | NULL if on-demand |
| from_user_id      | BIGINT FK users           |                   |
| to_user_id        | BIGINT FK users           |                   |
| message           | TEXT NOT NULL             |                   |
| read_at           | TIMESTAMPTZ               |                   |
| created_at        | TIMESTAMPTZ               |                   |

### Sprint 10 — Notifications & support

#### `notifications`

| Column     | Type                 | Notes                               |
| ---------- | -------------------- | ----------------------------------- |
| id         | BIGSERIAL PK         |                                     |
| user_id    | BIGINT FK users      |                                     |
| type       | VARCHAR(50) NOT NULL | TRIP_ACCEPTED, DRIVER_ARRIVED, etc. |
| title      | VARCHAR(200)         |                                     |
| body       | TEXT                 |                                     |
| data       | JSONB                | deep-link payload                   |
| channel    | VARCHAR(20)          | PUSH, SMS, IN_APP                   |
| sent_at    | TIMESTAMPTZ          |                                     |
| read_at    | TIMESTAMPTZ          |                                     |
| created_at | TIMESTAMPTZ          |                                     |

#### `support_tickets`

| Column                 | Type                       | Notes                                  |
| ---------------------- | -------------------------- | -------------------------------------- |
| id                     | BIGSERIAL PK               |                                        |
| public_id              | VARCHAR(20) UNIQUE         | `tkt_*`                                |
| user_id                | BIGINT FK users            |                                        |
| trip_id                | BIGINT FK trips            | optional context                       |
| category               | VARCHAR(50)                | PAYMENT, DRIVER_BEHAVIOR, SAFETY, etc. |
| subject                | VARCHAR(200)               |                                        |
| description            | TEXT                       |                                        |
| status                 | VARCHAR(20) DEFAULT 'OPEN' | OPEN, IN_PROGRESS, RESOLVED, CLOSED    |
| assigned_to_user_id    | BIGINT FK users            | admin                                  |
| resolved_at            | TIMESTAMPTZ                |                                        |
| created_at, updated_at | TIMESTAMPTZ                |                                        |

#### `device_tokens`

| Column       | Type            | Notes        |
| ------------ | --------------- | ------------ |
| id           | BIGSERIAL PK    |              |
| user_id      | BIGINT FK users |              |
| fcm_token    | TEXT NOT NULL   |              |
| platform     | VARCHAR(20)     | ANDROID, IOS |
| device_info  | JSONB           |              |
| last_seen_at | TIMESTAMPTZ     |              |
| created_at   | TIMESTAMPTZ     |              |

Unique (`user_id`, `fcm_token`).

## Indexes worth calling out

- `users (phone)` unique
- `vehicles (registration_number)` unique
- `driver_states USING GIST (current_location)`
- `trips (rider_user_id, created_at DESC)`
- `trips (driver_user_id, created_at DESC)`
- `trip_location_pings (trip_id, recorded_at)`
- `scheduled_trips USING GIST (route_line)`
- `scheduled_trips (departure_at) WHERE status = 'OPEN'`
- `notifications (user_id, created_at DESC) WHERE read_at IS NULL`

## PostGIS query patterns

### Find drivers within radius

```sql
SELECT user_id, ST_Distance(current_location, $1::geography) AS dist_m
FROM driver_states
WHERE status = 'ONLINE'
  AND current_vehicle_id IN (SELECT id FROM vehicles WHERE vehicle_type = $2)
  AND ST_DWithin(current_location, $1::geography, $3)
ORDER BY dist_m
LIMIT 10;
```

### Find scheduled trips matching rider's route (corridor search)

```sql
SELECT id, public_id, departure_at, price_per_seat
FROM scheduled_trips
WHERE status = 'OPEN'
  AND available_seats >= $4
  AND departure_at BETWEEN $5 AND $6
  AND ST_DWithin(route_line, $1::geography, 1000)  -- 1km corridor of rider pickup
  AND ST_DWithin(route_line, $2::geography, 1000)  -- and rider drop
ORDER BY departure_at;
```
