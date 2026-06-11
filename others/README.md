# Docs — Navigation Map

The project ships **three product surfaces** (backend, admin, mobile) built by three people. This folder is organized by surface so each person finds their own plan first, then dips into shared concerns.

## Read this first per role

| Role                          | Start with                                                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Backend engineer (you)        | [`ROADMAP.md`](ROADMAP.md) → [`sprints/SPRINT_0X.md`](sprints/)                                                     |
| Flutter dev (mobile)          | [`mobile/FLUTTER_HANDOFF.md`](mobile/FLUTTER_HANDOFF.md) → [`mobile/MOBILE_API_PLAN.md`](mobile/MOBILE_API_PLAN.md) |
| Admin builder (you, parallel) | [`admin/ADMIN_FEATURES.md`](admin/ADMIN_FEATURES.md) → [`admin/sprints/`](admin/sprints/)                           |
| Founder / PM                  | [`ROADMAP.md`](ROADMAP.md) → demo checklists in current sprint file                                                 |

## Folder layout

```
docs/
├── README.md                   ← you are here
├── ROADMAP.md                  ← master cross-product timeline
│
├── TECH_STACK.md               ← shared: stack decisions + rationale
├── API_CONVENTIONS.md          ← shared: URL, error, auth, pagination
├── DB_SCHEMA.md                ← shared: tables, PostGIS query patterns
├── GIT_WORKFLOW.md             ← shared: branches, commits, PRs
├── FREE_TIER_GUIDE.md          ← shared: how to run 100% free in dev + deploy
│
├── sprints/                    ← integration sprints — biweekly all-surface release
│   └── SPRINT_01.md … SPRINT_10.md   (1–4 foundations · 5 mobile auth · 6 safety · 7 trips · 8 payments · 9 carpool · 10 launch)
│
├── backend/                    ← backend-specific docs
│   ├── README.md
│   ├── ARCHITECTURE.md         ← module map, queues, services
│   └── ENV_VARS.md             ← env var catalog
│
├── admin/                      ← admin panel product surface
│   ├── README.md
│   ├── ADMIN_FEATURES.md       ← A-to-Z page-by-page spec
│   ├── ADMIN_ROADMAP.md        ← admin's own 8-sprint plan
│   └── sprints/
│       └── ADMIN_SPRINT_01.md … ADMIN_SPRINT_08.md
│
├── mobile/                     ← mobile (Flutter) product surface
│   ├── README.md
│   ├── FLUTTER_HANDOFF.md      ← one-page bootstrap for the 2 Flutter devs
│   ├── MOBILE_API_PLAN.md      ← A-to-Z screen-by-screen endpoint map
│   ├── MOBILE_ROADMAP.md       ← mobile's own 8-sprint plan
│   └── sprints/
│       └── MOBILE_SPRINT_01.md … MOBILE_SPRINT_08.md
│
└── testing/                    ← no-QA team's safety net
    ├── README.md
    ├── TESTING_STRATEGY.md     ← what gets tested how
    ├── BACKEND_TEST_PLAN.md
    ├── ADMIN_TEST_PLAN.md
    └── MOBILE_TEST_PLAN.md
```

## How the three roadmaps line up

The same biweekly rhythm. Each integration sprint produces shippable surfaces in all three places simultaneously.

| Wk    | Integration sprint          | Backend (you)             | Admin (you)             | Mobile (Flutter devs)                 |
| ----- | --------------------------- | ------------------------- | ----------------------- | ------------------------------------- |
| 1–2   | 01 — Foundation             | Auth API, deploy          | Login + dashboard shell | Project init, splash, mock auth       |
| 3–4   | 02 — Profiles & KYC         | KYC + vehicle APIs        | Driver approval queue   | Profile, KYC upload screens           |
| 5–6   | 03 — Maps & fare            | Geocode + fare engine     | Pricing rules editor    | Address book, fare quotes             |
| 7–8   | 04 — Matching               | Driver state + matching   | Live map page           | Driver online/offline + rider request |
| 9–10  | 05 — Mobile auth            | password login API        | App config page         | Full signup + login flow              |
| 11–12 | 06 — Safety + privacy       | SOS, share, CMS           | SOS feed + CMS UI       | SOS button, share trip, settings      |
| 13–14 | 07 — Trips & realtime       | Trip state + WS           | Trip detail + replay    | Live tracking, ratings                |
| 15–16 | 08 — Payments               | Razorpay + wallet         | Payments + payouts UI   | UPI checkout, wallet view             |
| 17–18 | 09 — Carpool                | Posted trips + bookings   | Scheduled trips admin   | Search + book + chat                  |
| 19–20 | 10 — Notifications & launch | FCM + support + hardening | Tickets + content CMS   | Notifications, support, polish        |

Beta launch end of week 20. Hard launch when founder has 50+ drivers ready.

## Conventions reminder

- Conventional commits per [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md)
- Money in integer paise, locations as `{lat,lng}`, timestamps ISO UTC
- Standard error envelope per [`API_CONVENTIONS.md`](API_CONVENTIONS.md)
- Free-tier first per [`FREE_TIER_GUIDE.md`](FREE_TIER_GUIDE.md)
