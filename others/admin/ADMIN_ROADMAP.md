# Admin Panel — Roadmap

> 8 admin sprints × 2 weeks. Backend has 10 sprints, so some admin sprints bundle multiple backend sprints (see "Backend dependency" column). Each admin sprint ships the UI for what backend shipped, so founder sees end-to-end value every demo.

## Timeline at a glance

| #   | Sprint                                                   | Theme                                        | Backend dependency | Status |
| --- | -------------------------------------------------------- | -------------------------------------------- | ------------------ | ------ |
| A01 | [Shell + Auth + Users](sprints/ADMIN_SPRINT_01.md)       | Login, dashboard shell, users list           | Backend 01         | ⬜     |
| A02 | [Drivers + KYC + Vehicles](sprints/ADMIN_SPRINT_02.md)   | KYC approval queue, vehicle approval         | Backend 02         | ⬜     |
| A03 | [Pricing + Maps](sprints/ADMIN_SPRINT_03.md)             | Pricing rules editor, reusable Map component | Backend 03         | ⬜     |
| A04 | [Live Map + Ride Requests](sprints/ADMIN_SPRINT_04.md)   | Realtime driver positions, requests list     | Backend 04         | ⬜     |
| A05 | [Trips + Ratings + SOS](sprints/ADMIN_SPRINT_05.md)      | Trip detail w/ replay, ratings, SOS feed     | Backend 07 + 6     | ⬜     |
| A06 | [Payments + Payouts](sprints/ADMIN_SPRINT_06.md)         | Payments list, refunds, payout queue         | Backend 08         | ⬜     |
| A07 | [Carpool + Chats](sprints/ADMIN_SPRINT_07.md)            | Scheduled trips, bookings, chat audit        | Backend 09         | ⬜     |
| A08 | [Support + Content + Launch](sprints/ADMIN_SPRINT_08.md) | Tickets, CMS, broadcast, analytics           | Backend 10 + 5     | ⬜     |

## Definition of "Admin sprint complete"

1. All pages listed for the sprint are routable
2. All endpoints listed in [`ADMIN_FEATURES.md`](ADMIN_FEATURES.md) for that sprint return data
3. Deployed to Vercel preview from `main`
4. Manual smoke checklist passed (see [testing/ADMIN_TEST_PLAN.md](../testing/ADMIN_TEST_PLAN.md))
5. Founder has clicked through the new pages

## Risks

| Risk                                                  | Mitigation                                                       |
| ----------------------------------------------------- | ---------------------------------------------------------------- |
| Admin work blocks backend feature delivery            | Admin is "last mile" — build only what's demo-able; defer polish |
| shadcn version churn                                  | Pin Tailwind v4 + shadcn CLI version in `package.json`           |
| Map page performance with many drivers                | Cluster pins above 50; throttle WS updates client-side           |
| Auth shared with mobile JWT but different role checks | Single backend, role-aware guards                                |

## Out of MVP (admin) — Phase 2+

- Multi-language admin UI
- Custom dashboard builder
- White-label theming per city
- 2FA for admin
- Granular role permissions beyond SUPER_ADMIN / ADMIN / SUPPORT
- Webhook subscriptions to external systems
- Notification template editor (currently read-only)
