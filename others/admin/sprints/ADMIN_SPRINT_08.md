# Admin Sprint A08 — Support, Content CMS, Analytics, Launch Polish

> **Duration:** 2 weeks (parallel with Backend Sprint 10)
> **Goal:** Founder resolves a real support ticket, publishes a new FAQ, suspends a fake account, reads yesterday's GMV report — all from admin.

## Scope

### Pages

- `/support/tickets` — queue with filter (status, category, assignee)
- `/support/tickets/[id]` — conversation, internal notes, assign / resolve actions
- `/support/lost-items` — subtype queue
- `/content` — list (FAQ / articles / legal), filter by language
- `/content/new` — markdown editor with live preview
- `/content/[id]` — edit + publish toggle + language tabs
- `/app-config` — edit support phone/email, terms URL, force-update flag
- `/users/[id]` (enhanced) — suspend / ban / unsuspend with reason; show audit log + sessions
- `/admins` — list admin users; create / change role / revoke
- `/audit` — global audit log
- `/reports/daily` — daily summary (rides, GMV, signups, completion rate)
- `/reports/drivers/leaderboard` — top earners by range
- `/reports/cancellations` — cancellation rate + reasons
- CSV export buttons on reports
- Dashboard KPI widgets fully populated

### Components

- `<MarkdownEditor>` — `@uiw/react-md-editor`
- `<TicketConversation>` — bubble UI w/ internal vs external messages
- `<SuspendBanDialog>` — typed confirmation
- `<ReportCard>` — KPI + sparkline
- `<KpiTile>` — large number + delta

### Tasks

- All admin endpoints from [`ADMIN_FEATURES.md`](../ADMIN_FEATURES.md) §13-19 wired
- CSV download by appending `?format=csv` and serving as Blob
- Test broadcast notification flow
- Polish: empty states, loading skeletons everywhere
- Pre-launch QA pass: every page reviewed against `ADMIN_TEST_PLAN.md`

## Endpoints consumed

- All `/admin/support/*`, `/admin/content/*`, `/admin/admins/*`, `/admin/audit`, `/admin/reports/*`, `/admin/notifications/*`, `/admin/users/:id/suspend|ban`, `/admin/app-config`

## Acceptance

- [ ] Ticket → reply → user receives push (verified)
- [ ] FAQ published → mobile app sees it after cache TTL (6h or manual refresh)
- [ ] Force-update flag flipped → mobile app shows update screen on next request
- [ ] Daily report shows yesterday's real numbers
- [ ] Banned user cannot log in
- [ ] All pages have proper empty states
- [ ] Tagged `v1.0.0-beta` for launch

## Git plan

- `feature/admin-a08-support-tickets`
- `feature/admin-a08-lost-items`
- `feature/admin-a08-content-cms`
- `feature/admin-a08-app-config`
- `feature/admin-a08-user-mgmt`
- `feature/admin-a08-admins`
- `feature/admin-a08-audit-log`
- `feature/admin-a08-reports`
- `feature/admin-a08-broadcast`
- `feature/admin-a08-polish`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
