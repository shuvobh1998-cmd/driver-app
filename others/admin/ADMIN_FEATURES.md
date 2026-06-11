# Admin Panel — A-to-Z Feature Spec

> Page-by-page spec for every admin screen. Mirrors the structure of [`../mobile/MOBILE_API_PLAN.md`](../mobile/MOBILE_API_PLAN.md). Each page lists its purpose, the endpoints it calls, the actions an admin can take, and which sprint delivers it.

---

## Status legend

| Tag | Meaning                                               |
| --- | ----------------------------------------------------- |
| ✅  | Live now (in `main`)                                  |
| 🔧  | Sprint 5 (mobile auth — admin gets app config editor) |
| 🛟  | Sprint 6 (mobile safety — admin gets SOS feed + CMS)  |
| ⏳  | Sprint 7 (trips + ratings)                            |
| 💰  | Sprint 8 (payments)                                   |
| 🚗  | Sprint 9 (scheduled carpool)                          |
| 🔔  | Sprint 10 (notifications + support + launch)          |

---

## 0. Shell, auth, navigation

| #   | Page                                                   | Endpoint(s)                                                 | Sprint |
| --- | ------------------------------------------------------ | ----------------------------------------------------------- | ------ |
| 0.1 | `/login` — admin email + password                      | `POST /api/v1/admin/auth/login`                             | ✅     |
| 0.2 | `/` (dashboard) — empty shell with sidebar/topbar      | n/a                                                         | ✅     |
| 0.3 | `/settings/me` — admin's own profile + change password | `GET /api/v1/auth/me` + `POST /api/v1/auth/password/change` | 🔧     |
| 0.4 | Sidebar with role-aware items                          | n/a                                                         | ✅     |
| 0.5 | `/logout` action                                       | `POST /api/v1/auth/logout`                                  | ✅     |

## 1. Dashboard (home)

| #   | Widget                                             | Endpoint                                      | Sprint  |
| --- | -------------------------------------------------- | --------------------------------------------- | ------- |
| 1.1 | Today's KPIs (rides, GMV, active drivers, signups) | `GET /api/v1/admin/dashboard/kpis?date=today` | 🔔      |
| 1.2 | Hourly trip volume chart                           | `GET /api/v1/admin/dashboard/trips-hourly`    | 🔔      |
| 1.3 | Active drivers on map (mini-map)                   | `GET /api/v1/admin/live-map/drivers`          | ✅      |
| 1.4 | Recent SOS events (last 24h)                       | `GET /api/v1/admin/safety/sos?from=...`       | 🛟      |
| 1.5 | Pending KYC count + payouts pending count          | aggregate calls                               | ✅ + 💰 |

## 2. Users

| #   | Page                                                                            | Endpoint(s)                                           | Sprint |
| --- | ------------------------------------------------------------------------------- | ----------------------------------------------------- | ------ |
| 2.1 | `/users` — list w/ search by phone/name, filter by role/status                  | `GET /api/v1/admin/users?q=&role=&status=&page=`      | ✅     |
| 2.2 | `/users/[id]` — detail (profile, trip count, wallet if driver, sessions, audit) | `GET /api/v1/admin/users/:id` + child calls           | ✅     |
| 2.3 | Edit user profile (admin override)                                              | `PATCH /api/v1/admin/users/:id`                       | 🔧     |
| 2.4 | Suspend / unsuspend                                                             | `POST /api/v1/admin/users/:id/suspend` + `/unsuspend` | 🔔     |
| 2.5 | Ban (permanent)                                                                 | `POST /api/v1/admin/users/:id/ban`                    | 🔔     |
| 2.6 | Force reset password (sends OTP to user)                                        | `POST /api/v1/admin/users/:id/force-password-reset`   | 🔧     |
| 2.7 | Sessions list + force-logout a device                                           | `GET /api/v1/admin/users/:id/sessions` + `DELETE`     | 🛟     |
| 2.8 | Audit log on this user                                                          | `GET /api/v1/admin/users/:id/audit`                   | 🔔     |
| 2.9 | Account deletion queue (users with pending deletion)                            | `GET /api/v1/admin/users?deletionPending=true`        | 🛟     |

## 3. Drivers

(Subset of users with DRIVER role; KYC + vehicle context.)

| #   | Page                                                            | Endpoint(s)                                                               | Sprint |
| --- | --------------------------------------------------------------- | ------------------------------------------------------------------------- | ------ |
| 3.1 | `/drivers` — list, filter by KYC status                         | `GET /api/v1/admin/drivers?kyc_status=...`                                | ✅     |
| 3.2 | `/drivers/[id]` — full profile + KYC docs + vehicles + earnings | `GET /api/v1/admin/drivers/:id`                                           | ✅     |
| 3.3 | Approve / reject KYC overall                                    | `POST /api/v1/admin/drivers/:id/kyc/approve` + `/reject`                  | ✅     |
| 3.4 | Per-document approve/reject                                     | `POST /api/v1/admin/drivers/:id/kyc/documents/:docId/approve` + `/reject` | ✅     |
| 3.5 | Approve / reject a vehicle                                      | `POST /api/v1/admin/vehicles/:id/approve` + `/reject`                     | ✅     |
| 3.6 | Driver earnings tab                                             | `GET /api/v1/admin/drivers/:id/earnings?range=...`                        | 💰     |
| 3.7 | Driver wallet ledger                                            | `GET /api/v1/admin/drivers/:id/wallet/ledger`                             | 💰     |
| 3.8 | Manual wallet adjustment (+/-)                                  | `POST /api/v1/admin/drivers/:id/wallet/adjust`                            | 💰     |
| 3.9 | Driver ratings + comments                                       | `GET /api/v1/admin/drivers/:id/ratings`                                   | ⏳     |

## 4. Vehicles

| #   | Page                                        | Endpoint(s)                                | Sprint |
| --- | ------------------------------------------- | ------------------------------------------ | ------ |
| 4.1 | `/vehicles` — queue + filter (status, type) | `GET /api/v1/admin/vehicles?status=&type=` | ✅     |
| 4.2 | `/vehicles/[id]` — photos, docs, owner link | `GET /api/v1/admin/vehicles/:id`           | ✅     |

## 5. Pricing

| #   | Page                                          | Endpoint(s)                                            | Sprint |
| --- | --------------------------------------------- | ------------------------------------------------------ | ------ |
| 5.1 | `/pricing` — current rules per vehicle type   | `GET /api/v1/admin/pricing-rules`                      | ✅     |
| 5.2 | Edit pricing rule (creates new effective row) | `POST /api/v1/admin/pricing-rules`                     | ✅     |
| 5.3 | `/pricing/history` — audit                    | `GET /api/v1/admin/pricing-rules/history?vehicleType=` | ✅     |
| 5.4 | `/pricing/cancellation-policy` editor         | `GET` + `PATCH /api/v1/admin/cancellation-policies`    | 💰     |

## 6. Maps & locations

| #   | Page                                                      | Endpoint(s)                                                         | Sprint |
| --- | --------------------------------------------------------- | ------------------------------------------------------------------- | ------ |
| 6.1 | `/live-map` — real-time driver positions, WS subscription | `GET /api/v1/admin/live-map/drivers` + WS `driver.location.updated` | ✅     |
| 6.2 | User saved addresses (on user detail)                     | `GET /api/v1/admin/users/:id/addresses`                             | ✅     |

## 7. Ride requests (on-demand)

| #   | Page                                     | Endpoint(s)                                         | Sprint |
| --- | ---------------------------------------- | --------------------------------------------------- | ------ |
| 7.1 | `/rides/requests` — list with filters    | `GET /api/v1/admin/ride-requests?status=&from=&to=` | ✅     |
| 7.2 | `/rides/requests/[id]` — detail with map | `GET /api/v1/admin/ride-requests/:id`               | ✅     |
| 7.3 | Force-cancel a stuck request             | `POST /api/v1/admin/ride-requests/:id/cancel`       | ✅     |

## 8. Trips

| #   | Page                                                                           | Endpoint(s)                             | Sprint |
| --- | ------------------------------------------------------------------------------ | --------------------------------------- | ------ |
| 8.1 | `/trips` — list + filter (status, vehicle, date, driver, rider)                | `GET /api/v1/admin/trips?...`           | ⏳     |
| 8.2 | `/trips/[id]` — detail with map replay, timeline, fare breakdown, both ratings | `GET /api/v1/admin/trips/:id` (+ pings) | ⏳     |
| 8.3 | `/trips/[id]/live` — real-time view for in-progress                            | WS `trip:{id}` events                   | ⏳     |
| 8.4 | Force-cancel a trip (admin override)                                           | `POST /api/v1/admin/trips/:id/cancel`   | ⏳     |
| 8.5 | Trip chat audit (if any)                                                       | `GET /api/v1/admin/trips/:id/chat`      | 🚗     |

## 9. Scheduled carpool (firti gari)

| #   | Page                                                 | Endpoint(s)                                     | Sprint |
| --- | ---------------------------------------------------- | ----------------------------------------------- | ------ |
| 9.1 | `/scheduled-trips` — list + filter                   | `GET /api/v1/admin/scheduled-trips?status=...`  | 🚗     |
| 9.2 | `/scheduled-trips/[id]` — detail w/ route + bookings | `GET /api/v1/admin/scheduled-trips/:id`         | 🚗     |
| 9.3 | Force-cancel                                         | `POST /api/v1/admin/scheduled-trips/:id/cancel` | 🚗     |
| 9.4 | `/bookings` — all bookings                           | `GET /api/v1/admin/bookings?...`                | 🚗     |
| 9.5 | `/bookings/[id]` — detail                            | `GET /api/v1/admin/bookings/:id`                | 🚗     |

## 10. Payments

| #    | Page                                                 | Endpoint(s)                              | Sprint |
| ---- | ---------------------------------------------------- | ---------------------------------------- | ------ |
| 10.1 | `/payments` — list w/ filters (method, status, date) | `GET /api/v1/admin/payments?...`         | 💰     |
| 10.2 | `/payments/[id]` — detail + Razorpay reference       | `GET /api/v1/admin/payments/:id`         | 💰     |
| 10.3 | Issue refund (full / partial)                        | `POST /api/v1/admin/payments/:id/refund` | 💰     |

## 11. Payouts

| #    | Page                       | Endpoint(s)                                          | Sprint |
| ---- | -------------------------- | ---------------------------------------------------- | ------ |
| 11.1 | `/payouts` — pending queue | `GET /api/v1/admin/payouts?status=PENDING`           | 💰     |
| 11.2 | Approve / reject           | `POST /api/v1/admin/payouts/:id/approve` + `/reject` | 💰     |
| 11.3 | Mark paid with UTR         | `POST /api/v1/admin/payouts/:id/mark-paid`           | 💰     |
| 11.4 | `/payouts/history`         | `GET /api/v1/admin/payouts?status=PAID`              | 💰     |

## 12. Chats (audit-only)

| #    | Page                                         | Endpoint(s)                                  | Sprint |
| ---- | -------------------------------------------- | -------------------------------------------- | ------ |
| 12.1 | `/chats` — recent threads (audit, read-only) | `GET /api/v1/admin/chats?...`                | 🚗     |
| 12.2 | `/chats/[id]` — full thread                  | `GET /api/v1/admin/chats/:id`                | 🚗     |
| 12.3 | Flag / hide message                          | `POST /api/v1/admin/chats/messages/:id/flag` | 🚗     |

## 13. Notifications (tools)

| #    | Page                                                               | Endpoint(s)                                  | Sprint |
| ---- | ------------------------------------------------------------------ | -------------------------------------------- | ------ |
| 13.1 | `/notifications/preview` — send test notification by type + user   | `POST /api/v1/admin/notifications/test-send` | 🔔     |
| 13.2 | `/notifications/templates` — view template strings (read-only MVP) | `GET /api/v1/admin/notifications/templates`  | 🔔     |
| 13.3 | `/notifications/broadcasts` — broadcast to all users (rare)        | `POST /api/v1/admin/notifications/broadcast` | 🔔     |

## 14. Support

| #    | Page                                                   | Endpoint(s)                                       | Sprint |
| ---- | ------------------------------------------------------ | ------------------------------------------------- | ------ |
| 14.1 | `/support/tickets` — queue + filters                   | `GET /api/v1/admin/support/tickets?...`           | 🔔     |
| 14.2 | `/support/tickets/[id]` — conversation, internal notes | `GET /api/v1/admin/support/tickets/:id`           | 🔔     |
| 14.3 | Assign to admin                                        | `POST /api/v1/admin/support/tickets/:id/assign`   | 🔔     |
| 14.4 | Reply                                                  | `POST /api/v1/admin/support/tickets/:id/messages` | 🔔     |
| 14.5 | Resolve / close                                        | `POST /api/v1/admin/support/tickets/:id/resolve`  | 🔔     |
| 14.6 | `/support/lost-items` — subtype queue                  | `GET /api/v1/admin/support/lost-items`            | 🔔     |

## 15. Safety / SOS

| #    | Page                                                                     | Endpoint(s)                                     | Sprint |
| ---- | ------------------------------------------------------------------------ | ----------------------------------------------- | ------ |
| 15.1 | `/safety/sos` — live feed                                                | `GET /api/v1/admin/safety/sos?status=OPEN` + WS | 🛟     |
| 15.2 | `/safety/sos/[id]` — detail (driver, rider, contacts notified, location) | `GET /api/v1/admin/safety/sos/:id`              | 🛟     |
| 15.3 | Mark resolved with notes                                                 | `POST /api/v1/admin/safety/sos/:id/resolve`     | 🛟     |

## 16. Content / CMS

| #    | Page                                             | Endpoint(s)                       | Sprint |
| ---- | ------------------------------------------------ | --------------------------------- | ------ |
| 16.1 | `/content` — list pages (FAQ / articles / legal) | `GET /api/v1/admin/content?...`   | 🛟     |
| 16.2 | `/content/new` — markdown editor                 | `POST /api/v1/admin/content`      | 🛟     |
| 16.3 | `/content/[id]` — edit + publish toggle          | `PATCH /api/v1/admin/content/:id` | 🛟     |
| 16.4 | Language switcher per page (en / bn / hi)        | linked via `slug + language`      | 🛟     |

## 17. App config

| #    | Page                                                                                    | Endpoint(s)                              | Sprint |
| ---- | --------------------------------------------------------------------------------------- | ---------------------------------------- | ------ |
| 17.1 | `/app-config` — edit support phone/email, terms URL, force-update flag, latest versions | `GET` + `PATCH /api/v1/admin/app-config` | 🔧     |
| 17.2 | Vehicle type config (label, icon URL) — for `/app/config` rider sees                    | embedded in 17.1                         | 🔧     |

## 18. Analytics / Reports

| #    | Page                                                   | Endpoint(s)                                        | Sprint |
| ---- | ------------------------------------------------------ | -------------------------------------------------- | ------ |
| 18.1 | `/reports/daily` — yesterday's numbers                 | `GET /api/v1/admin/reports/daily?date=...`         | 🔔     |
| 18.2 | `/reports/drivers/leaderboard` — top earners this week | `GET /api/v1/admin/reports/drivers/top?range=week` | 🔔     |
| 18.3 | `/reports/cancellations` — rate, reasons               | `GET /api/v1/admin/reports/cancellations`          | 🔔     |
| 18.4 | CSV export buttons on every report                     | append `&format=csv`                               | 🔔     |

## 19. Admin team management

| #    | Page                         | Endpoint(s)                               | Sprint |
| ---- | ---------------------------- | ----------------------------------------- | ------ |
| 19.1 | `/admins` — list admin users | `GET /api/v1/admin/admins`                | 🔔     |
| 19.2 | Create admin / change role   | `POST` + `PATCH /api/v1/admin/admins/:id` | 🔔     |
| 19.3 | Revoke admin                 | `DELETE /api/v1/admin/admins/:id`         | 🔔     |

## 20. Audit log (global)

| #    | Page                                      | Endpoint(s)                                        | Sprint |
| ---- | ----------------------------------------- | -------------------------------------------------- | ------ |
| 20.1 | `/audit` — every admin action, filterable | `GET /api/v1/admin/audit?actor=&action=&from=&to=` | 🔔     |

---

## Design guidelines (admin-wide)

- **Layout:** persistent left sidebar (collapsible), topbar with breadcrumbs + admin avatar + logout, content area scrolls
- **Tables:** server-side pagination, sortable columns, sticky header, row-click → detail page (not modal)
- **Forms:** modal for short edits (suspend with reason), full page for multi-section (vehicle edit, content editor)
- **Confirmations:** destructive actions (ban, refund, cancel trip) require typed confirmation ("type DELETE to confirm")
- **Status badges:** colored chips for KYC status, trip status, payment status — use a shared `<StatusBadge>` component
- **Maps:** Leaflet + OSM tiles via `react-leaflet`; reusable `<Map>` and `<TripReplayMap>` components
- **Empty states:** illustration + clear CTA — never an empty table
- **Loading:** skeleton rows for tables, spinners for actions
- **Error:** toast (sonner) for action errors; full-page error boundary for page-level
- **Optimistic updates:** for low-risk actions (mark read, flag) — for money/state actions, wait for server confirmation

## Auth & role model in admin

- Admin login uses email + password (separate from user phone auth)
- Roles: `SUPER_ADMIN`, `ADMIN`, `SUPPORT`
- Sidebar items filtered by role (SUPPORT can only see Users + Support + Safety)
- Destructive actions (ban, refund, content publish) require `ADMIN` or higher

## What admin will NOT do

- Edit user passwords directly (only force-reset = sends OTP to user)
- Send mass emails (broadcast is push only)
- Edit Postgres directly (always through APIs with audit log)
- Mock payments — refunds only

---

## Tech notes per surface

- Tables: `@tanstack/react-table` for sorting/filtering/column resize
- Forms: `react-hook-form` + Zod schemas, share schemas with backend if possible
- Maps: `react-leaflet` (free, OSM tiles)
- Charts: `recharts`
- Markdown editor: `@uiw/react-md-editor`
- Toasts: `sonner`
- Modals: shadcn `Dialog`
- Date range: shadcn `Calendar` + `react-day-picker`
