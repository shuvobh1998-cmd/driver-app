# Mobile Sprint M03 — Driver Onboarding (KYC + Vehicles + Driver Home)

> **Duration:** 2 weeks
> **Goal:** A user toggles "I want to drive", uploads Aadhaar/DL/RC + vehicle photo, waits for KYC approval, then goes online from the driver home and sees their location plotted on admin's live map.

## Scope

### Screens

- Role switcher (in profile / drawer): "Become a driver" CTA → calls upgrade endpoint
- KYC upload checklist (Aadhaar, DL, RC, Insurance, optional Permit) — each row: upload status + view
- Document upload bottom sheet: camera / gallery picker
- Vehicle registration form: type, make, model, color, plate, seat count
- Vehicle photo upload
- "Waiting for approval" screen with KYC status badge
- Driver home: map with own location + big "Go Online" button (vehicle dropdown if multiple) + earnings chip
- Online state: map shows own pin, location pings every 5s
- Vehicle selector (if more than one approved vehicle)

### Components

- `DocUploadRow` — pending / uploaded / approved / rejected states
- `VehicleCard` — photo, plate, status badge
- `DriverGoOnlineButton` — large, accessible, prominent
- `LiveLocationPinger` — background service / timer

### Permissions

- Camera + storage (for KYC + vehicle photos)
- Always location (for driver online mode — needed even when app backgrounded)
- Notifications (FCM — wired in M08)

## Endpoints integrated

- `POST /api/v1/users/me/upgrade-to-driver`
- `POST /api/v1/drivers/me/profile`
- `GET /api/v1/drivers/me/profile`
- `POST /api/v1/drivers/me/kyc/documents`
- `GET /api/v1/drivers/me/kyc/documents`
- `DELETE /api/v1/drivers/me/kyc/documents/:id`
- `GET /api/v1/drivers/me/kyc/status`
- `POST /api/v1/drivers/me/vehicles`
- `GET /api/v1/drivers/me/vehicles`
- `POST /api/v1/drivers/me/vehicles/:id/photo`
- `POST /api/v1/drivers/me/online`
- `POST /api/v1/drivers/me/offline`
- `POST /api/v1/drivers/me/location`
- `GET /api/v1/drivers/me/state`

## Acceptance

- [ ] Rider upgrades to driver successfully
- [ ] All 4 KYC docs upload (image resize to ≤1024px wide, JPEG q80)
- [ ] Vehicle registered + photo uploaded
- [ ] KYC pending → can't go online; rejected → see reason; approved → can go online
- [ ] Online → location pings every 5s; admin sees pin on `/live-map`
- [ ] Offline button works; pin disappears from admin

## Status

- [x] Backend API delivered + verified end-to-end (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable = the backend endpoints + Swagger the Flutter team consumes.
> Every M03 endpoint already shipped in Sprints 2–4; this sprint closed two gaps
> the driver onboarding flow exposed and verified the whole flow against the real stack.

**Fixed this sprint**

- **Go-online now gates on KYC.** Previously only the vehicle's ACTIVE status was
  checked, so a driver with an approved vehicle but un-approved KYC could go online.
  `POST /drivers/me/online` now returns `KYC_INCOMPLETE` (403) for pending/in-review/
  no-profile and `KYC_REJECTED` (403, with `details.rejectedReason`) for a rejected
  driver, before the vehicle check. The vehicle-not-approved case now returns
  `VEHICLE_NOT_APPROVED` (403) to match the mobile error catalog (was VEHICLE_NOT_ACTIVE/409).
- **Vehicle `:id` routes now use the public id.** `PATCH`/`DELETE`/`POST .../photo`
  on `/drivers/me/vehicles/:id` required the numeric DB id, which the API never
  returns — so the vehicle-photo upload was unreachable. They now accept the
  `veh_*` public id, consistent with `/drivers/me/online`.

**Already live (verified this sprint)**

- `POST /users/me/upgrade-to-driver`
- `POST`/`GET`/`PATCH /drivers/me/profile`
- `POST`/`GET`/`DELETE /drivers/me/kyc/documents`, `GET /drivers/me/kyc/status`
- `POST`/`GET /drivers/me/vehicles`, `POST /drivers/me/vehicles/:id/photo`
- `POST /drivers/me/online` · `offline` · `location` · `GET /drivers/me/state`
- Admin: `GET /admin/live-map/drivers`, KYC + vehicle approve/reject

**End-to-end verification** (real Supabase PostGIS + Redis, fresh rider "Arjun Roy"):
upgrade → driver profile → upload AADHAAR + DL → register vehicle + photo →
go-online **blocked KYC_INCOMPLETE (403)** → admin approves KYC + vehicle →
go-online **200 ONLINE** → location ping 200 → **driver pin appears on admin
live-map** → go-offline → **pin gone** → offline ping rejected DRIVER_NOT_ONLINE.
252 unit tests green (+6 new).

## Notes

- **DB migrations 0011–0015 were unapplied on the dev DB** and were deployed this
  sprint (`prisma migrate deploy`) — `users.password_set_at` (from M01) was missing,
  which 500'd upgrade-to-driver. Anything touching `users` needs these applied.
- **`:id` for a vehicle is its `veh_*` public id** (not a number) — true for the
  driver-facing routes. Admin vehicle approve/reject still uses the numeric id
  (internal surface).
- KYC requires AADHAAR + DL at minimum (RC/Insurance/Permit optional). `kyc/status`
  returns `uploaded`/`required`/`missing`/`rejectedReason`. Approval is admin-driven.
