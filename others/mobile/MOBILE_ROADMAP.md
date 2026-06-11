# Mobile (Flutter) — Roadmap

> 8 mobile sprints × 2 weeks. Backend has 10 sprints, so some mobile sprints bundle multiple backend sprints (see "Backend dependency" column). **Both rider and driver flows ship in ONE Flutter binary** (role-aware home, toggle between modes). Two Flutter devs work in parallel: Dev A = rider tracks, Dev B = driver tracks.

## Timeline

| #   | Sprint                                                         | Theme                                                        | Backend dependency | Status |
| --- | -------------------------------------------------------------- | ------------------------------------------------------------ | ------------------ | ------ |
| M01 | [Setup + Auth + Profile](sprints/MOBILE_SPRINT_01.md)          | Project init, splash, signup, login, profile, app config     | Backend 1 + 5      | ⬜     |
| M02 | [Maps + Addresses + Rider home](sprints/MOBILE_SPRINT_02.md)   | Saved places, geocode, fare quote, rider home shell          | Backend 3          | ⬜     |
| M03 | [Driver onboarding](sprints/MOBILE_SPRINT_03.md)               | KYC upload, vehicle add, driver home shell, online toggle    | Backend 2 + 4      | ⬜     |
| M04 | [On-demand booking flow](sprints/MOBILE_SPRINT_04.md)          | Rider: request → matched. Driver: receive offer → accept     | Backend 4          | ⬜     |
| M05 | [Trip lifecycle + ratings](sprints/MOBILE_SPRINT_05.md)        | Arrived → start (OTP) → end. Live map. History. Ratings.     | Backend 7          | ⬜     |
| M06 | [Payments + wallet](sprints/MOBILE_SPRINT_06.md)               | Razorpay UPI, saved methods, invoices, driver wallet, payout | Backend 8          | ⬜     |
| M07 | [Carpool + chat](sprints/MOBILE_SPRINT_07.md)                  | Post / search / book scheduled trips, chat                   | Backend 9          | ⬜     |
| M08 | [Notifications + safety + launch](sprints/MOBILE_SPRINT_08.md) | FCM, SOS, share trip, support, polish, app store prep        | Backend 10 + 6     | ⬜     |

## Parallel tracks

| Sprint | Dev A (rider focus)                                       | Dev B (driver focus)                                  |
| ------ | --------------------------------------------------------- | ----------------------------------------------------- |
| M01    | Splash, signup, login, profile screens                    | Auth same, then settings shell                        |
| M02    | Address book, autocomplete, map screen, fare quote        | Help Dev A; start preparing driver shell              |
| M03    | (light) — polish + start booking screen                   | KYC upload, vehicle add, driver home, online toggle   |
| M04    | Booking flow (request, "finding driver", matched, cancel) | Driver offer card, accept/decline, go to pickup       |
| M05    | Trip detail w/ live tracking, rating screen, history      | Trip lifecycle (arrived, OTP entry, in-progress, end) |
| M06    | Razorpay UPI flow, payment methods, invoice viewer        | Wallet, ledger, payout request                        |
| M07    | Carpool search + book + my bookings + chat                | Carpool post + manage + chat                          |
| M08    | FCM setup, notifications inbox, SOS button, support       | FCM, settings polish, store prep                      |

## Definition of "Mobile sprint complete"

1. All screens listed in the sprint file are built + navigable
2. All endpoints listed are integrated (no mocks left)
3. Critical paths covered by widget / integration tests (see [testing/MOBILE_TEST_PLAN.md](../testing/MOBILE_TEST_PLAN.md))
4. Tested on 1 real Android device (Android 12+) + iOS Simulator
5. APK built and shared with founder for demo

## Foundation decisions

| Topic          | Choice                                             | Why                                           |
| -------------- | -------------------------------------------------- | --------------------------------------------- |
| State mgmt     | `riverpod` (recommended) or `bloc`                 | Either works; pick one and stick              |
| Navigation     | `go_router`                                        | Declarative, deep-link friendly               |
| HTTP           | `dio`                                              | Interceptors for auth + 401 refresh           |
| Local DB       | `drift` (or `shared_preferences` for simple cases) | Only if needed for offline                    |
| Models         | OpenAPI codegen (`openapi-generator-cli`)          | Types from Swagger; no manual JSON parsing    |
| Maps           | `flutter_map` (free, OSM)                          | Switch to `google_maps_flutter` at prod scale |
| Theming        | One light theme + one dark; Material 3             | Follow system preference                      |
| Localization   | `flutter_localizations` + `.arb` files             | en + bn + hi for launch                       |
| Push           | `firebase_messaging`                               | iOS APNs is auto-bridged                      |
| Payments       | `razorpay_flutter`                                 | Standard Indian choice                        |
| WebSocket      | `socket_io_client`                                 | Matches backend                               |
| Secure storage | `flutter_secure_storage`                           | Refresh token only                            |
| Test framework | `flutter_test` + `integration_test`                | Standard                                      |

## Out of MVP (mobile) — Phase 2+

- Apple Pay / Wallet integration
- In-app calling (use phone deep-link for MVP)
- Biometric login
- Voice navigation / TTS
- Tablet layouts
- Wear OS / watch integration
- Offline mode beyond cached tiles
- Promo code redemption UI
- Referral tracking
- Multi-account switching
