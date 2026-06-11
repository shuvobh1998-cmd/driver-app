# Admin Sprint A02 — Drivers, KYC, Vehicles

> **Duration:** 2 weeks (parallel with Backend Sprint 2)
> **Goal:** Founder opens a real driver in admin, views uploaded Aadhaar/DL/RC + vehicle photo, clicks Approve → driver gets a push notification.

## Scope

### Pages

- `/drivers` — list filterable by KYC status; columns: name, phone, vehicles count, KYC status, joined date
- `/drivers/[id]` — full detail: profile, KYC docs (each with viewer), vehicles list, action buttons (approve / reject / suspend)
- `/vehicles` — separate vehicle approval queue (status filter)
- `/vehicles/[id]` — photos + linked driver

### Components

- `<KycDocViewer>` — image lightbox + PDF inline iframe
- `<ApproveRejectModal>` — confirmation w/ optional reason
- `<DriverAvatar>` — initials fallback

### Tasks

- Page routes
- Approve/reject mutations (TanStack Query) with optimistic refresh
- Signed-URL pattern for KYC images (URLs have 1h TTL — refresh on view)
- Filter chips for KYC status

## Endpoints consumed

- `GET /api/v1/admin/drivers?kyc_status=&page=`
- `GET /api/v1/admin/drivers/:id`
- `POST /api/v1/admin/drivers/:id/kyc/approve` + `/reject`
- `POST /api/v1/admin/drivers/:id/kyc/documents/:docId/approve` + `/reject`
- `GET /api/v1/admin/vehicles?status=&page=`
- `GET /api/v1/admin/vehicles/:id`
- `POST /api/v1/admin/vehicles/:id/approve` + `/reject`

## Acceptance

- [ ] Driver list shows realistic counts per KYC status
- [ ] Detail page renders all docs without broken images
- [ ] Approve KYC → status updates + push lands on driver app (verified in backend logs)
- [ ] Reject with reason → driver sees rejection reason
- [ ] Vehicle approval flow works independently

## Git plan

- `feature/admin-a02-drivers-list`
- `feature/admin-a02-driver-detail`
- `feature/admin-a02-kyc-viewer`
- `feature/admin-a02-approval-actions`
- `feature/admin-a02-vehicles`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
