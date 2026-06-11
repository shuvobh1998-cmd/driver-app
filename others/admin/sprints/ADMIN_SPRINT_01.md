# Admin Sprint A01 — Shell, Auth, Users

> **Duration:** 2 weeks (parallel with Backend Sprint 1)
> **Goal:** Founder logs into admin panel, sees a real user appear in the users table when someone signs up.

## Scope

### Pages

- `/login` — email + password form, redirects on success
- `/` (dashboard) — sidebar + topbar + empty welcome card with sprint pointer
- `/users` — paginated table: phone, name, roles, status, created date; search by phone or email
- `/settings/me` — basic admin profile view (read only this sprint)

### Components

- `<DashboardLayout>` — sidebar + topbar + content
- `<DataTable>` — TanStack Table wrapper (sorting, pagination)
- `<StatusBadge>` — colored chip
- `<SearchInput>` — debounced 300ms
- API client `lib/api.ts` — dio-equivalent fetch wrapper with 401 auto-refresh

### Tasks

- Init Next.js 14 + Tailwind v4 + shadcn CLI
- Install: `@tanstack/react-query`, `@tanstack/react-table`, `react-hook-form`, `zod`, `sonner`, `react-leaflet`, `recharts`
- Configure NextAuth or simple JWT-cookie auth against `POST /api/v1/admin/auth/login`
- Wire env var `NEXT_PUBLIC_API_BASE_URL`
- Auth interceptor + automatic refresh on 401
- ESLint + Prettier matching backend style
- Deploy to Vercel from `main`

## Endpoints consumed

- `POST /api/v1/admin/auth/login`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/logout`
- `GET /api/v1/admin/users?q=&page=`

## Acceptance

- [ ] Admin can log in from Vercel URL
- [ ] Dashboard loads with sidebar
- [ ] Users page lists at least the seeded admin user
- [ ] Search by phone returns matching user
- [ ] Logout works
- [ ] 401 triggers refresh attempt; if refresh fails, kick to login
- [ ] Deployed to Vercel + auto-deploys on push

## Git plan

- `feature/admin-a01-bootstrap` — Next.js init + Tailwind + shadcn
- `feature/admin-a01-layout` — DashboardLayout + sidebar
- `feature/admin-a01-auth` — login page + JWT cookie + interceptor
- `feature/admin-a01-users-list` — paginated users table

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
