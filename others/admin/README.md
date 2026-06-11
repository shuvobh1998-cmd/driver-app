# Admin Panel — Next.js + shadcn

Built by the same engineer who owns the backend. Lives in `/admin/` directory of the repo. Deployed to Vercel.

## Read these

| File                                     | Purpose                                                          |
| ---------------------------------------- | ---------------------------------------------------------------- |
| [`ADMIN_FEATURES.md`](ADMIN_FEATURES.md) | A-to-Z page-by-page spec (like MOBILE_API_PLAN.md but for admin) |
| [`ADMIN_ROADMAP.md`](ADMIN_ROADMAP.md)   | 8-sprint plan for admin pages, mirrors backend sprints           |
| [`sprints/`](sprints/)                   | Per-sprint detail (what to build per 2-week iteration)           |

## Stack

- Next.js 14 (App Router)
- shadcn/ui (copy-paste components)
- Tailwind CSS
- TanStack Query for data fetching
- React Hook Form + Zod
- Leaflet + OSM tiles
- Recharts for analytics
- NextAuth (or simple JWT cookie) for admin auth

## Conventions

- Pages live under `app/(dashboard)/<feature>/page.tsx`
- Shared layout: sidebar + topbar via `app/(dashboard)/layout.tsx`
- Reusable components in `components/ui/` (shadcn) and `components/<feature>/`
- API client in `lib/api.ts` — single instance with auth header + 401 refresh
- Data fetching via `useQuery` / `useMutation`
- Forms via `react-hook-form` + Zod schemas matching backend DTOs

## Hosting

- **Dev**: Vercel preview from `main` branch
- **Prod**: Vercel production
- Env var: `NEXT_PUBLIC_API_BASE_URL` points at backend Fly.io URL
