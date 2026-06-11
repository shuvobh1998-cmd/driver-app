# Mobile — Flutter app (rider + driver in one binary)

Built by 2 Flutter developers. Backend engineer owns the API contract. This folder is everything Flutter devs need.

## Read in order

1. [`FLUTTER_HANDOFF.md`](FLUTTER_HANDOFF.md) — one-page bootstrap (URLs, test creds, conventions)
2. [`MOBILE_API_PLAN.md`](MOBILE_API_PLAN.md) — 27-section A-to-Z screen → endpoint mapping
3. [`MOBILE_ROADMAP.md`](MOBILE_ROADMAP.md) — 8-sprint plan with track A (rider) / track B (driver)
4. [`sprints/`](sprints/) — per-sprint detail

## Stack (Flutter dev's choice — these are recommendations)

| Need             | Package                                                                   |
| ---------------- | ------------------------------------------------------------------------- |
| HTTP             | `dio`                                                                     |
| Secure storage   | `flutter_secure_storage`                                                  |
| State management | `riverpod` or `bloc`                                                      |
| Maps             | `flutter_map` (OSM, free) — switch to `google_maps_flutter` at production |
| WebSocket        | `socket_io_client`                                                        |
| Payments         | `razorpay_flutter`                                                        |
| Push             | `firebase_messaging`                                                      |
| Image picker     | `image_picker`                                                            |
| PIN entry        | `pin_code_fields`                                                         |

## Repo layout

Mobile app lives in a separate Git repo (not in this backend monorepo). Recommended structure for Flutter team:

```
lib/
├── core/
│   ├── api/                 # dio + interceptors
│   ├── ws/                  # socket.io client
│   ├── storage/             # secure storage wrapper
│   └── theme/
├── features/
│   ├── auth/                # signup, login, OTP, forgot
│   ├── profile/
│   ├── home_rider/
│   ├── home_driver/
│   ├── booking/             # on-demand rider flow
│   ├── trip/                # shared trip lifecycle
│   ├── carpool/             # scheduled trips
│   ├── chat/
│   ├── payments/
│   ├── wallet_driver/
│   ├── kyc_driver/
│   ├── notifications/
│   ├── safety/              # SOS + share trip
│   ├── support/
│   └── settings/
└── shared/
    ├── widgets/
    └── models/              # generated from OpenAPI

```

## Backend coordination

- Slack channel: `#rideshare-backend`
- Issues: GitHub Issues on backend repo with `mobile` label
- New endpoint requests: open issue with screen mockup + desired payload
- Daily standup recommended once trip lifecycle work starts (Sprint 5)
