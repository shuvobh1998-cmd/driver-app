# Sprint 2 — Profiles & KYC

> **Duration:** 2 weeks
> **Theme:** User profile CRUD, driver KYC document upload, vehicle management, admin approval workflow

## Goal

Founder approves a real driver end-to-end in the admin panel: views uploaded Aadhaar/DL/RC, checks vehicle photo, and clicks Approve.

## Why this sprint

Drivers can't take trips until KYC is approved. Without this sprint, even if matching works later (Sprint 4), no real driver can transact. Also, admin's first "real" workflow.

## Features

### 1. User profile

- `GET /api/v1/users/me/profile`
- `PATCH /api/v1/users/me/profile` — first/last name, email, DOB, gender
- `POST /api/v1/users/me/avatar` — multipart upload, returns URL

### 2. Driver profile + KYC

- `POST /api/v1/drivers/me/profile` — create driver profile (adds DRIVER role)
- `GET /api/v1/drivers/me/profile`
- `PATCH /api/v1/drivers/me/profile` — emergency contact, etc.
- `POST /api/v1/drivers/me/kyc/documents` — multipart, doc_type + file
- `GET /api/v1/drivers/me/kyc/documents` — list own docs
- `DELETE /api/v1/drivers/me/kyc/documents/:id`
- `GET /api/v1/drivers/me/kyc/status` — overall status

### 3. Vehicle management

- `POST /api/v1/drivers/me/vehicles` — register a vehicle
- `GET /api/v1/drivers/me/vehicles`
- `PATCH /api/v1/drivers/me/vehicles/:id`
- `DELETE /api/v1/drivers/me/vehicles/:id` (soft)
- `POST /api/v1/drivers/me/vehicles/:id/photo` — multipart

### 4. Admin — Driver approval

- `GET /api/v1/admin/drivers` — paginated, filterable (`status`, `kyc_status`, search by phone/name)
- `GET /api/v1/admin/drivers/:userId` — full profile + docs + vehicles
- `POST /api/v1/admin/drivers/:userId/kyc/approve`
- `POST /api/v1/admin/drivers/:userId/kyc/reject` — body: `{ reason }`
- `POST /api/v1/admin/vehicles/:id/approve`
- `POST /api/v1/admin/vehicles/:id/reject` — body: `{ reason }`

### 5. Storage layer

- Supabase Storage bucket `kyc-docs` (private, signed URLs only)
- Service wrapper that uploads + returns signed URL with 1h TTL
- Doc numbers encrypted at rest (Postgres pgcrypto or app-layer AES)

### 6. Admin panel pages

- `/drivers` — list with KYC status badge
- `/drivers/[id]` — detail page with doc viewer (image lightbox / PDF inline), approve/reject buttons with reason modal
- `/vehicles` — separate vehicle approval queue

### 7. Notifications (minimal, push only)

- On KYC approved → push to driver: "You're approved — go online!"
- On KYC rejected → push: "Action needed: {reason}"
- (Full notification system in Sprint 10 — this sprint uses raw FCM SDK call)

## API endpoints delivered

(see Features above)

## DB migrations this sprint

1. `0002_driver_profiles` — `driver_profiles` table
2. `0003_kyc_documents` — `kyc_documents` table
3. `0004_vehicles` — `vehicles` table

## Admin panel pages this sprint

| Page            | Purpose                                     |
| --------------- | ------------------------------------------- |
| `/drivers`      | List all drivers with KYC filter            |
| `/drivers/[id]` | Driver detail + KYC viewer + approve/reject |
| `/vehicles`     | Vehicle approval queue                      |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + Swagger + Postman. No Flutter code from us.

**Endpoints shipped:**

- User profile: `GET/PATCH /api/v1/users/me/profile`, `POST /api/v1/users/me/avatar`
- Driver profile + KYC: `POST/GET/PATCH /api/v1/drivers/me/profile`, `POST/GET /api/v1/drivers/me/kyc/documents`, `DELETE /api/v1/drivers/me/kyc/documents/:id`, `GET /api/v1/drivers/me/kyc/status`
- Vehicles: `POST/GET /api/v1/drivers/me/vehicles`, `PATCH/DELETE /api/v1/drivers/me/vehicles/:id`, `POST /api/v1/drivers/me/vehicles/:id/photo`
- Device tokens (push registration): `POST /api/v1/notifications/device-tokens`, `POST /api/v1/notifications/device-tokens/unregister`

**WebSocket events:** none yet.

**Conventions Flutter must match:**

- File uploads use `multipart/form-data` (NOT JSON)
- Max file size: 5MB
- Accepted MIME: `image/jpeg`, `image/png`, `image/webp`, `application/pdf` (KYC only)

**Artifacts:**

- Postman collection: `docs/postman/sprint-02.json`
- Sample KYC test images in repo

**Unblocks mobile sprint M02** — profile screens, KYC upload, vehicle registration. See [`docs/mobile/sprints/MOBILE_SPRINT_02.md`](../mobile/sprints/MOBILE_SPRINT_02.md).

## Demo checklist

- [ ] Driver registers via Postman → uploads Aadhaar + DL + RC + vehicle photo
- [ ] Admin opens `/drivers`, sees the new driver as PENDING
- [ ] Admin opens detail page, views all uploaded docs
- [ ] Admin clicks Approve → driver receives push notification (or shown in admin)
- [ ] Founder rejects a fake doc with a reason → driver sees rejection reason

## Definition of Done

- [ ] All endpoints + admin pages functional
- [ ] Signed URLs work for doc viewing in admin
- [ ] File upload size/type validation enforced
- [ ] e2e tests for KYC happy path + reject path
- [ ] Approval/rejection audit logged
- [ ] Push notification triggers on approve/reject
- [ ] Git tag `v0.2.0-sprint-2` pushed

## Git plan

- `feature/sprint-2-user-profile` — profile CRUD + avatar
- `feature/sprint-2-driver-profile` — driver profile + KYC docs
- `feature/sprint-2-vehicles` — vehicle CRUD + photo
- `feature/sprint-2-admin-approval` — admin endpoints + UI
- `feature/sprint-2-storage` — Supabase storage wrapper
- `feature/sprint-2-kyc-push` — minimal FCM call on approve/reject

## Status

- [ ] Not started
- [x] In progress
- [ ] Done

### Feature progress

- [x] 1. User profile — `GET/PATCH /users/me/profile` + `POST /users/me/avatar` (multipart, 5MB cap, jpeg/png/webp). New `Gender` enum + `dob`/`gender`/`avatar_url` columns on `users` via migration `0002_user_profile_fields`. Avatar storage abstracted behind `StorageService` interface; ships with a local-disk implementation (`@fastify/static` mounted at `/static`) which Feature 5 will swap for Supabase Storage.
- [x] 2. Driver profile + KYC — `POST/GET/PATCH /drivers/me/profile`, `POST/GET /drivers/me/kyc/documents`, `DELETE /drivers/me/kyc/documents/:id`, `GET /drivers/me/kyc/status`. New `driver_profiles` + `kyc_documents` tables with `KycStatus` / `KycDocType` enums via migration `0003_driver_profiles_and_kyc`. Creating a driver profile is idempotent and adds the `DRIVER` role. KYC upload reuses the Feature 1 `StorageService` (5MB cap, jpeg/png/webp/pdf), unique on `(userId, docType)` so re-upload replaces; upload auto-flips `PENDING`/`REJECTED` → `IN_REVIEW`, and deleting the last doc reverts `IN_REVIEW` → `PENDING`. Required docs for `kyc/status`: AADHAAR + DL.
- [x] 3. Vehicle management — `POST/GET /drivers/me/vehicles`, `PATCH/DELETE /drivers/me/vehicles/:id`, `POST /drivers/me/vehicles/:id/photo`. New `vehicles` table with `VehicleType` (BIKE/AUTO/CNG/CAR) + `VehicleStatus` (PENDING_APPROVAL/ACTIVE/INACTIVE) enums via migration `0004_vehicles`. Register requires an existing driver profile; `registrationNumber` is globally unique and locked once set. PATCH allows make/model/year/color/seatCount only. DELETE is soft (sets `deletedAt` + `status=INACTIVE`); list excludes soft-deleted. Photo upload reuses the `StorageService` (jpeg/png/webp, 5MB) under prefix `vehicles/<userId>/<vehiclePublicId>`; replaces the prior file when extension changes.
- [x] 4. Admin — Driver approval — `GET /admin/drivers` (paginated, filter by `status`/`kycStatus`/`search`), `GET /admin/drivers/:userPublicId` (profile + KYC docs + vehicles), `POST /admin/drivers/:userPublicId/kyc/{approve,reject}`, `POST /admin/vehicles/:id/{approve,reject}`. New role-based auth: `@Roles(UserRole.ADMIN)` decorator + global `RolesGuard` (after `JwtAuthGuard`) — 403 `FORBIDDEN` for non-admins. New `Paginated<T>` envelope + extended response interceptor (`data` + `pagination: { page, pageSize, total, hasMore }` per API_CONVENTIONS.md). KYC approve refuses while still `PENDING` (no docs submitted) with 409 `INVALID_STATE`. Approve/reject write `approvedAt`/`approvedByUserId` (or clear them on reject) and emit a structured `audit: kyc.*` / `audit: vehicle.*` log line.
- [x] 5. Storage layer (Supabase) — `StorageService` interface extended with `visibility: 'public' \| 'private'`, `getSignedUrl(key, { ttlSeconds, visibility })`, and `remove(key, { visibility })`. New `SupabaseStorageService` implementation behind the same interface; `StorageModule` factory-provides Local or Supabase based on `STORAGE_PROVIDER` env (default `local`). KYC docs now upload to the private bucket with `visibility='private'`; every read (driver self-list + admin detail) regenerates a fresh 1-hour signed URL. Avatars + vehicle photos move to the public bucket. KYC `doc_number` is encrypted at rest via AES-256-GCM (`FieldEncryptionService`, key from `KYC_DOC_NUMBER_KEY` env) with `enc:v1:<base64>` ciphertext layout and a legacy plain-text fallback for backwards compat. New env vars: `STORAGE_PROVIDER`, `STORAGE_BUCKET_PUBLIC`, `STORAGE_BUCKET_PRIVATE`, `KYC_DOC_NUMBER_KEY`.
- [x] 6. Admin panel pages — `/drivers` list with filters (`status`, `kycStatus`, search) + pagination; `/drivers/[userPublicId]` detail with KYC docs grid (image preview / PDF icon, links to signed URL in new tab, decrypted doc number), approve/reject KYC and per-vehicle approve/reject with a shared reason-modal dialog; `/vehicles` queue (defaults to `PENDING_APPROVAL`, filterable by status + type) with inline approve/reject. Backend gains `GET /api/v1/admin/vehicles` (paginated, defaults to `PENDING_APPROVAL`, joins owner phone/name) and now exposes the vehicle numeric `id` in the admin detail response so the UI can call `/admin/vehicles/:id/{approve,reject}`. New admin-panel components: `ui/badge`, `ui/dialog` (radix), `ui/textarea`, `ui/table`, plus `status-badge`, `reject-dialog`, and an `apiRequestPaginated` helper that splits the `{ data, pagination }` envelope. Sidebar enables Drivers + Vehicles links and activates by path prefix so child routes stay highlighted.
- [x] 7. Notifications (push on approve/reject) — new `device_tokens` table + `DevicePlatform` enum via migration `0005_device_tokens`. Mobile clients call `POST /api/v1/notifications/device-tokens` (idempotent upsert on `(userId, fcmToken)`, refreshes `lastSeenAt`) after sign-in and on every Firebase token refresh, and `POST /api/v1/notifications/device-tokens/unregister` on sign-out. `FirebaseAdminService` gains `sendToTokens()` (multicast via `sendEachForMulticast`) which reports permanently-invalid tokens so callers can prune. `NotificationsService.sendToUser()` looks up the user's tokens, calls FCM, and deletes any that came back invalid. KYC approve / reject in `AdminDriversService` fire a push fire-and-forget — failures are caught in `NotificationsService` and logged so an FCM outage cannot block the admin response. Sprint 10 will move the push call onto a BullMQ queue and broaden the notification surface (trip events, payment receipts, etc.).

## Delivered

> Fill at end of sprint.

## Carryover

> Anything pushed to Sprint 3.

## Notes / Blockers

> Capture decisions, gotchas.
