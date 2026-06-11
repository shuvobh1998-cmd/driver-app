# Roadmap — Cross-Product Master Plan

> Master timeline across **3 product surfaces** (backend, admin, mobile). Each surface has its own roadmap; this is how they line up.

## Vision

Build a Kolkata-focused ride-sharing platform combining:

- **Uber/Rapido-style on-demand** (bike, auto, CNG, car)
- **BlaBlaCar-style scheduled carpool — "firti gari"** (driver posts return trip, riders book a seat)

**MVP = both modes live in one city with at least 50 verified drivers and end-to-end safety + payment.**

## Per-surface roadmaps

| Surface                    | Owner          | Roadmap                                                |
| -------------------------- | -------------- | ------------------------------------------------------ |
| Backend (NestJS + Fastify) | You            | `sprints/SPRINT_01.md` … `SPRINT_10.md`                |
| Admin (Next.js + shadcn)   | You            | [`admin/ADMIN_ROADMAP.md`](admin/ADMIN_ROADMAP.md)     |
| Mobile (Flutter)           | 2 Flutter devs | [`mobile/MOBILE_ROADMAP.md`](mobile/MOBILE_ROADMAP.md) |

## Timeline alignment (20 weeks)

| Wk    | Integration sprint                                  | Backend (you)             | Admin (you)                             | Mobile (Flutter devs)                     |
| ----- | --------------------------------------------------- | ------------------------- | --------------------------------------- | ----------------------------------------- |
| 1–2   | [01 — Foundation](sprints/SPRINT_01.md)             | Auth API, deploy          | [A01](admin/sprints/ADMIN_SPRINT_01.md) | [M01](mobile/sprints/MOBILE_SPRINT_01.md) |
| 3–4   | [02 — Profiles & KYC](sprints/SPRINT_02.md)         | KYC + vehicle APIs        | [A02](admin/sprints/ADMIN_SPRINT_02.md) | [M03](mobile/sprints/MOBILE_SPRINT_03.md) |
| 5–6   | [03 — Maps & Fare](sprints/SPRINT_03.md)            | Geocode + fare engine     | [A03](admin/sprints/ADMIN_SPRINT_03.md) | [M02](mobile/sprints/MOBILE_SPRINT_02.md) |
| 7–8   | [04 — Matching](sprints/SPRINT_04.md)               | Driver state + matching   | [A04](admin/sprints/ADMIN_SPRINT_04.md) | [M04](mobile/sprints/MOBILE_SPRINT_04.md) |
| 9–10  | [05 — Mobile Auth](sprints/SPRINT_05.md)            | Password login + signup   | App config UI                           | Full auth flow                            |
| 11–12 | [06 — Safety + Privacy](sprints/SPRINT_06.md)       | SOS, share trip, CMS      | SOS feed + CMS UI                       | SOS button + share + settings             |
| 13–14 | [07 — Trips & Realtime](sprints/SPRINT_07.md)       | Trip state + WS           | [A05](admin/sprints/ADMIN_SPRINT_05.md) | [M05](mobile/sprints/MOBILE_SPRINT_05.md) |
| 15–16 | [08 — Payments](sprints/SPRINT_08.md)               | Razorpay + wallet         | [A06](admin/sprints/ADMIN_SPRINT_06.md) | [M06](mobile/sprints/MOBILE_SPRINT_06.md) |
| 17–18 | [09 — Carpool](sprints/SPRINT_09.md)                | Posted trips + bookings   | [A07](admin/sprints/ADMIN_SPRINT_07.md) | [M07](mobile/sprints/MOBILE_SPRINT_07.md) |
| 19–20 | [10 — Notifications & Launch](sprints/SPRINT_10.md) | FCM + support + hardening | [A08](admin/sprints/ADMIN_SPRINT_08.md) | [M08](mobile/sprints/MOBILE_SPRINT_08.md) |

**Total: 20 weeks (~5 months) to beta-launch ready.** Adjust honestly if scope shifts.

## Where to read the deep detail

| You're looking for                      | Read                                                         |
| --------------------------------------- | ------------------------------------------------------------ |
| Backend feature spec per sprint         | [`sprints/SPRINT_0X.md`](sprints/)                           |
| Every admin page mapped to endpoints    | [`admin/ADMIN_FEATURES.md`](admin/ADMIN_FEATURES.md)         |
| Every mobile screen mapped to endpoints | [`mobile/MOBILE_API_PLAN.md`](mobile/MOBILE_API_PLAN.md)     |
| Flutter devs' one-page bootstrap        | [`mobile/FLUTTER_HANDOFF.md`](mobile/FLUTTER_HANDOFF.md)     |
| How everything is tested                | [`testing/TESTING_STRATEGY.md`](testing/TESTING_STRATEGY.md) |
| Backend architecture                    | [`backend/ARCHITECTURE.md`](backend/ARCHITECTURE.md)         |
| Env var catalog                         | [`backend/ENV_VARS.md`](backend/ENV_VARS.md)                 |
| Free-tier deploy guide                  | [`FREE_TIER_GUIDE.md`](FREE_TIER_GUIDE.md)                   |

## Risk register

| Risk                                                   | Severity  | Mitigation                                                                  |
| ------------------------------------------------------ | --------- | --------------------------------------------------------------------------- |
| No driver network yet                                  | 🔴 High   | Founder must recruit 50+ drivers during Sprints 1-8                         |
| Solo backend bottleneck                                | 🔴 High   | API-first + mocks unblock Flutter devs; Claude assist for boilerplate       |
| 2-month founder expectation vs 4-month reality         | 🟡 Medium | Re-anchor at each sprint demo with progress visible                         |
| Free-tier hitting limits in real test                  | 🟡 Medium | Upgrade individual services only when limits hit (see `FREE_TIER_GUIDE.md`) |
| Maps cost explosion at scale                           | 🟡 Medium | Start OSM/Mapbox; move to OLA Maps (cheaper than Google) at launch          |
| Razorpay live KYC delays                               | 🟡 Medium | Apply for live keys early in Sprint 8, not Sprint 10                        |
| WB transport dept aggregator compliance                | 🟡 Medium | Founder to confirm legal review before beta launch                          |
| App store rejection (privacy / deletion / permissions) | 🟡 Medium | Sprint 6 ships account deletion + clear permission prompts                  |

## Out of MVP (Phase 2+)

- Surge pricing
- Subscription / pass for riders
- Corporate accounts
- Multi-city expansion
- Driver subscription model
- iOS-specific features (Apple Pay, CallKit)
- Loyalty / referral system
- Promo codes
- Multi-language admin UI
- In-app calling (use phone deep-link for MVP)
- Advanced analytics dashboard

## Definition of "Integration sprint complete"

A sprint is **Done** only when all three surfaces deliver:

1. **Backend** — all endpoints in `SPRINT_0X.md` merged + deployed
2. **Admin** — all pages in `ADMIN_SPRINT_0X.md` deployed to Vercel
3. **Mobile** — all screens in `MOBILE_SPRINT_0X.md` shipped to internal testers
4. CI green on all three repos
5. Postman collection updated
6. Founder has seen the demo end-to-end
7. Sprint docs updated with **Delivered** + any **Carryover**
8. Git tags created on backend repo: `v0.X.0-sprint-X`
