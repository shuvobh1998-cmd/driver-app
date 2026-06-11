# Admin Sprint A03 — Pricing & Map Component

> **Duration:** 2 weeks (parallel with Backend Sprint 3)
> **Goal:** Founder edits AUTO per-km from ₹12 to ₹14 in admin, sees the change reflected in a fare estimate.

## Scope

### Pages

- `/pricing` — table per vehicle type: base, per-km, per-min, min fare, platform fee, GST, effective from
- Edit modal (creates new effective rule)
- `/pricing/history` — full audit
- `/users/[id]/addresses` — show user's saved places on a map

### Components

- `<Map>` — reusable Leaflet wrapper with controlled center/zoom, marker support
- `<PricingForm>` — react-hook-form + Zod schema
- `<HistoryTimeline>` — vertical changes list

### Tasks

- Leaflet + OSM tile config
- Reusable map with prop API (`center`, `zoom`, `markers`, `polyline`, `onMarkerClick`)
- Pricing CRUD wired to admin endpoints
- History view paginated

## Endpoints consumed

- `GET /api/v1/admin/pricing-rules`
- `POST /api/v1/admin/pricing-rules`
- `GET /api/v1/admin/pricing-rules/history?vehicleType=`
- `GET /api/v1/admin/users/:id/addresses`

## Acceptance

- [ ] Pricing changes are atomic + audit row appears
- [ ] Map component renders OSM tiles + marker correctly
- [ ] User's saved addresses render as map pins

## Git plan

- `feature/admin-a03-map-component`
- `feature/admin-a03-pricing-list`
- `feature/admin-a03-pricing-edit`
- `feature/admin-a03-pricing-history`
- `feature/admin-a03-user-addresses`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
