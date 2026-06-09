# Driver App — Flutter Sprint Plan

> A **standalone Flutter app for drivers only** (separate binary from the rider app).
> Goal: a driver signs up, submits KYC + vehicle, gets approved, goes online, runs
> trips, and gets paid — all in a clean, low-friction, one-hand-on-the-wheel UI.
>
> Backend is **done and verified** — every endpoint below already ships in the deployed
> API. This plan only covers the Flutter build and is self-contained (each sprint lists the
> exact endpoints + WebSocket events it consumes).
>
> **7 sprints × 2 weeks each.** Each sprint ends with a runnable APK demoed to the founder.

---

## 1. Product principles (driver UX)

Drivers use this app while moving, in sunlight, often one-handed. Design for that:

| Principle | What it means in practice |
| --- | --- |
| **Big touch targets** | Primary actions ≥ 56dp height, full-width. The "Go Online" and "Accept" buttons dominate their screens. |
| **Glanceable state** | The driver always knows: am I online? do I have a trip? what's today's earning? — visible without scrolling. |
| **One decision per screen** | Offer screen = accept/decline only. Trip screen = the single next action (Arrived → Start → End). No clutter. |
| **Forgiving input** | KYC/vehicle forms autosave drafts, allow retake of photos, show inline validation, never lose work on a failed upload. |
| **Loud, time-boxed alerts** | A trip offer is a full-screen takeover with countdown + sound + haptics, not a small banner. |
| **High contrast, large type** | Sunlight-readable. Min body text 16sp. Status uses color **and** icon **and** label (never color alone). |
| **Trust & money clarity** | Earnings, commission, and wallet are always shown in ₹ from integer paise, never ambiguous. |

**Design system (build in Sprint D1):** Material 3, one light theme + one dark (follow
OS), a single `AppColors` / `AppText` / `AppSpacing` source of truth, reusable
`PrimaryButton`, `StatusBadge`, `AppScaffold`, `EmptyState`, `ErrorState`, `LoadingState`.
No screen hand-rolls colors or paddings.

---

## 2. Tech foundation (decided up front)

| Topic | Choice | Notes |
| --- | --- | --- |
| State mgmt | **Riverpod** | Async providers map cleanly to API + WS streams. |
| Navigation | **go_router** | Auth-guard redirect; deep links for FCM. |
| HTTP | **dio** | Interceptors: attach access token, auto-refresh on `TOKEN_EXPIRED`, `Idempotency-Key` on money/state POSTs. |
| Models | **OpenAPI codegen** from Swagger | No hand-written JSON. Regenerate per backend change. |
| Secure storage | **flutter_secure_storage** | Refresh token only; access token in memory. |
| Maps | **flutter_map** (OSM) | Free; swap to Google Maps at prod scale. |
| WebSocket | **socket_io_client** | `/driver` namespace, JWT in connect query. |
| Location | **geolocator** + **flutter_background_geolocation** (or a foreground service) | Background pings every ~5s while online. |
| Push | **firebase_messaging** + **flutter_local_notifications** | Full-screen trip-offer notification. |
| Payments | **razorpay_flutter** | Only for completeness; driver mostly cash/wallet. |
| Image | **image_picker** + **flutter_image_compress** | Resize KYC/vehicle photos to ≤1024px wide, JPEG q80. |
| Local DB | **drift** (only where offline matters: KYC draft, queued location pings) | Keep minimal. |
| Tests | **flutter_test** + **integration_test** + **mocktail** | Critical paths only. |

**Non-negotiable conventions (from handoff):** money in integer paise; locations as
`{lat,lng}`; ISO-8601 UTC; `Idempotency-Key` on every money/state-changing POST;
branch on `error.code`, never message text; WS auth via connect-query token.

**Environments:** `dev` / `staging` / `prod` flavors with separate base URLs and
Firebase configs. Ship a build-time `--dart-define` for the API base.

---

## 3. Sprint 0 — Project setup & scaffolding (3–4 days, before D1)

> Pure foundation: **no user-facing feature.** Done when the app compiles in all three
> flavors and shows a single themed placeholder screen. Everything after this just drops
> features into the agreed structure.

### Deliverables
- Flutter project created; `pubspec.yaml` with the §2 packages pinned.
- **Build flavors** `dev` / `staging` / `prod` via `--dart-define` (API base URL, Firebase config, env name) + entrypoints `main_dev.dart` / `main_staging.dart` / `main_prod.dart`.
- **Folder structure** below committed, with one placeholder per layer so the shape is real.
- Design-system skeleton: `AppColors`, `AppText`, `AppSpacing`, `AppTheme` (light + dark, Material 3) wired into `MaterialApp.router`.
- `dio` client skeleton + base `ApiClient` (interceptors stubbed, no logic yet).
- `go_router` with a single placeholder route + redirect hook (filled in D1).
- Riverpod `ProviderScope` at root; `flutter_gen` / l10n (`.arb`) initialized with en/bn/hi stubs.
- OpenAPI codegen script (`make models` or a `dart run` task) producing the models package.
- Lint (`flutter_lints` + custom rules), `analysis_options.yaml`, formatting, pre-commit hook.
- CI: build + analyze + test on every push; produces a debug APK artifact.
- README: how to run each flavor, regenerate models, run tests.

### Folder structure (feature-first)

```
lib/
  main_dev.dart  main_staging.dart  main_prod.dart   # flavor entrypoints
  app/
    app.dart                # MaterialApp.router root
    router/                 # go_router config + guards
    di/                     # provider overrides / bootstrap
  core/
    config/                 # env, AppConfig (from /app/config)
    network/                # dio client, interceptors (auth, refresh, idempotency, error)
    storage/                # secure token store, drift db
    websocket/              # socket_io_client wrapper (/driver namespace)
    location/               # LiveLocationService (foreground/bg pings)
    error/                  # error.code → message map, failures
    push/                   # firebase_messaging + local notifications
  design_system/
    colors.dart  typography.dart  spacing.dart  theme.dart
    widgets/                # PrimaryButton, StatusBadge, AppScaffold,
                            # EmptyState, ErrorState, LoadingState, AppTextField
  shared/
    extensions/  utils/     # formatPaise(), date helpers, validators
  features/
    auth/                   # D1
    onboarding_kyc/         # D2  (upgrade, docs, vehicles, approval)
    driver_home/            # D3  (online toggle, location)
    trips/                  # D4  (offer, lifecycle, ratings, history)
    earnings/               # D5  (earnings, wallet, payouts)
    carpool/                # D6  (scheduled trips, chat)
    notifications/          # D7  (inbox, sos, share, support)
    settings/               # profile, preferences, sessions
  l10n/                     # app_en.arb, app_bn.arb, app_hi.arb
gen/  models/               # OpenAPI-generated DTOs (codegen output)
```

> Each `features/<name>/` uses three layers: `data/` (repositories + api),
> `domain/` (entities + use-cases if needed), `presentation/` (screens + controllers + widgets).

### Acceptance
- [ ] `flutter run --flavor dev` (and staging/prod) launches a themed placeholder screen.
- [ ] Light/dark theme follows the OS; design-system tokens are the only source of styling.
- [ ] `dio` client builds with stubbed interceptors; OpenAPI models generate cleanly.
- [ ] CI is green: analyze + test + debug-APK artifact on push.

---

## 4. Sprint map

| # | Sprint | Theme | Backend area | Key outcome |
| --- | --- | --- | --- | --- |
| **D0** | Project setup & scaffolding | Structure, flavors, design-system + API-client skeletons, CI (3–4 days) | — | App compiles in all flavors, themed placeholder runs. |
| **D1** | Foundation + Auth | Project scaffold, design system, API client, splash, signup, login, profile | Bootstrap, Auth, Profile | Driver can create an account, log in, stay logged in, edit profile. |
| **D2** | **KYC + Vehicle submission** ⭐ | Upgrade-to-driver, document upload checklist, vehicle registration, approval-status screen | Driver onboarding, KYC & vehicles | Driver submits all docs + a vehicle and tracks approval. |
| **D3** | Go online + location | Driver home, vehicle selector, online/offline, background location pings, live state | Driver online/location | Approved driver goes online; pin shows on admin live-map. |
| **D4** | Trip lifecycle | Full-screen offer, accept/decline, navigate to pickup, Arrived → OTP-start → End, ratings, history | Trip offers + lifecycle + WS | Driver runs an end-to-end trip in-app. |
| **D5** | Earnings, wallet & payouts | Earnings dashboard, wallet ledger, cash-collected close, payout method + withdrawal | Driver payments/wallet | Driver sees money and withdraws it. |
| **D6** | Carpool + chat | Post/manage scheduled trips, bookings, start/complete, 1:1 chat | Scheduled trips + chat + WS | Driver runs scheduled-carpool trips and chats with riders. |
| **D7** | Notifications, safety & launch | FCM inbox, SOS, live-share, support tickets, settings polish, store prep | Notifications, safety, support + WS | Production-ready, store-submittable build. |

> ⭐ D2 is the centerpiece of this request (KYC + submission). D1 must land first
> because every D2 call is authenticated.

---

## D1 — Foundation + Auth

**Goal:** A driver can sign up with phone+OTP, set a password, log in, persist their
session across restarts, and edit their profile — on top of a reusable design system
and a hardened API client.

### Screens
- **Splash** — read refresh token → call `/auth/me` → route to home or login. Force-update check from `/app/config`.
- **Phone entry** (signup + login share the keypad).
- **OTP entry** — `pin_code_fields`, resend timer.
- **Complete profile** — first/last name, email, gender, password + retype, optional emergency contact.
- **Login** — phone/email + password; "forgot password" → OTP reset.
- **Profile** — view/edit name, email, gender, avatar upload.
- **Settings shell** — language (en/bn/hi), preferences, sessions list, logout, delete-account request.

### Components / infra
- Design system tokens + `PrimaryButton`, `StatusBadge`, `AppScaffold`, `EmptyState`, `ErrorState`, `LoadingState`, `AppTextField`.
- `dio` client with: token attach, `Idempotency-Key` generator, 401→refresh→retry interceptor, global error→`error.code` mapper.
- `SecureTokenStore`, `AuthController` (Riverpod), `go_router` auth guard.
- OpenAPI model codegen wired into the build.

### Endpoints
`GET /health` · `GET /app/config` · `POST /auth/otp/send` · `POST /auth/otp/verify` ·
`POST /auth/signup/start` · `/signup/verify-otp` · `/signup/complete` · `POST /auth/login` ·
`/auth/password/forgot/request` · `/forgot/reset` · `/password/change` · `POST /auth/refresh` ·
`POST /auth/logout` · `GET /auth/me` · `GET/PATCH /users/me/profile` · `POST /users/me/avatar` ·
`GET/PATCH /users/me/preferences` · `GET/DELETE /users/me/sessions/:id`.

### Acceptance
- [ ] Fresh signup → lands on home with a valid session.
- [ ] Kill + relaunch → still logged in (refresh-token restore works).
- [ ] Expired access token transparently refreshes; failed refresh kicks to login.
- [ ] Profile edit + avatar upload persist and reflect after relaunch.
- [ ] Force-update flag from `/app/config` blocks an outdated build.
- [ ] All errors render from `error.code`, with a friendly message map.

---

## D2 — KYC + Vehicle submission ⭐

**Goal:** A signed-in user taps "Become a driver", uploads every required KYC document,
registers a vehicle with a photo, and watches a clear approval status — with drafts that
survive failed uploads and a UI that never leaves them guessing what's missing.

> KYC minimum = **AADHAAR + DL** (RC / Insurance / Permit optional). `kyc/status` returns
> per-doc `uploaded` / `required` / `missing` plus `rejectedReason`. Approval is admin-driven.
> A vehicle's `:id` in driver routes is its `veh_*` public id.

### Screens
- **Become-a-driver intro** — what's needed, est. time, CTA → `upgrade-to-driver`, then create driver profile.
- **Onboarding checklist (hub)** — progress stepper: ① Documents ② Vehicle ③ Review. Each shows completion %.
- **KYC document checklist** — one `DocUploadRow` per doc type (Aadhaar, DL, RC, Insurance, optional Permit) with state: _missing · uploaded · in-review · approved · rejected (+reason)_.
- **Document capture sheet** — camera / gallery, live preview, **retake**, auto-compress to ≤1024px JPEG q80, optional `docNumber` field, upload with progress + retry.
- **Vehicle registration form** — type (Bike/Auto/CNG/Car), make, model, color, plate (`registrationNumber`), seat count; inline validation.
- **Vehicle photo upload** — same capture/compress pipeline.
- **My vehicles list** — `VehicleCard` (photo, plate, status badge); edit / soft-delete; add another.
- **Approval status screen** — overall KYC badge (pending / in-review / approved / rejected), what's blocking go-online, and a "What happens next" explainer. Rejected → show reason + one-tap re-upload.

### Components
- `DocUploadRow` — five visual states, with thumbnail + action.
- `UploadController` — compress → multipart `file` → progress → retry; persists a **local draft** (drift) so a dropped upload resumes.
- `VehicleCard`, `OnboardingStepper`, `KycStatusBadge`.

### Endpoints
`POST /users/me/upgrade-to-driver` · `POST/GET/PATCH /drivers/me/profile` ·
`POST/GET/DELETE /drivers/me/kyc/documents` · `GET /drivers/me/kyc/status` ·
`POST/GET /drivers/me/vehicles` · `PATCH/DELETE /drivers/me/vehicles/:id` ·
`POST /drivers/me/vehicles/:id/photo`.

### Acceptance
- [ ] Rider→driver upgrade succeeds; driver profile created.
- [ ] Aadhaar + DL + a vehicle + vehicle photo all upload (compressed, ≤5MB).
- [ ] Each doc row reflects live `kyc/status` (missing/required/uploaded/rejected+reason).
- [ ] A killed upload resumes from the saved draft — no lost work.
- [ ] Rejected doc shows the reason and supports one-tap re-upload.
- [ ] Approval status screen correctly states whether the driver can yet go online.
- [ ] `KYC_INCOMPLETE` / `KYC_REJECTED` / `VEHICLE_NOT_APPROVED` are handled with clear copy.

---

## D3 — Go online + location

**Goal:** An approved driver picks a vehicle, taps a big "Go Online", and the app streams
their location every ~5s (even backgrounded) so admin/matching sees them live — and goes
offline cleanly.

### Screens
- **Driver home** — map centered on self, prominent `DriverGoOnlineButton`, today's-earnings chip, vehicle selector (if >1 approved), online/offline status header.
- **Online state** — own pin updates live; subtle "you're online" banner; trip-search shimmer.
- **Permission primer** — explains "Always" location + battery exemption before the OS prompt.

### Components
- `DriverGoOnlineButton` (large, state-aware, haptic).
- `LiveLocationService` — foreground/background service; ~5s pings; **queues pings when offline-network and flushes on reconnect**; stops on go-offline.
- `DriverStateController` — single source of truth for online/offline/has-trip.

### Endpoints / WS
`POST /drivers/me/online` (`vehicleId`) · `POST /drivers/me/offline` ·
`POST /drivers/me/location` · `GET /drivers/me/state`. Connect `/driver` WS namespace.

### Acceptance
- [ ] Go-online blocked with correct message when KYC/vehicle not approved.
- [ ] Online → location pings every ~5s; **driver pin appears on admin `/live-map`**.
- [ ] App backgrounded → pings continue (foreground service notification shown).
- [ ] Offline → pings stop, pin disappears, state persists across relaunch.
- [ ] Network blip while online → pings queue and flush, no duplicate-state bugs.

---

## D4 — Trip lifecycle

**Goal:** While online, the driver receives a full-screen trip offer, accepts it, navigates
to pickup, marks Arrived, starts with the rider's OTP, ends the trip, and rates the rider —
driven by WebSocket events with REST as the source of truth.

### Screens
- **Incoming offer (full-screen takeover)** — pickup/drop, distance, est. fare, **countdown ring** + sound + haptics, Accept / Decline. Auto-dismiss on expiry.
- **Active trip** — map + route, the single next action button (`Navigate` → `Arrived` → `Start (OTP)` → `End`), rider name/phone (deep-link call), trip notes, cancel (pre-start) with reason.
- **OTP-to-start sheet** — 4-digit entry; `OTP_INVALID` / `OTP_REQUIRED` handling.
- **Trip summary** — fare breakdown, distance/time, payment method, "Rate rider".
- **Rate rider** — stars + optional comment.
- **Trip history** — paginated list + trip detail; report-a-problem.

### Components
- `TripOfferOverlay` (route-level, interrupts any screen; backed by FCM full-screen intent when app is backgrounded/killed).
- `ActiveTripController` — subscribes to `trip.*` WS events, reconciles with `GET /drivers/me/trips/current`.
- `NextActionButton` — derives the one allowed action from trip status.

### Endpoints / WS
Offer: `POST /drivers/me/trip-offers/:offerId/accept|decline`.
Lifecycle: `GET /drivers/me/trips`, `/trips/current`, `GET /trips/:id`,
`POST /trips/:id/arrived|start|end|cancel|rate-rider|report`.
WS: `trip.offered`, `trip.status.changed`, `trip.driver.arrived`, `trip.location.updated`,
`trip.completed`, `trip.cancelled`; publish `trip.subscribe` + `trip.location` (in-trip stream).

### Acceptance
- [ ] Offer arrives as a full-screen takeover **even when app is backgrounded/killed** (FCM).
- [ ] Accept creates the trip; decline / expiry returns driver to searching.
- [ ] Arrived → Start requires correct OTP; wrong OTP shows `OTP_INVALID`.
- [ ] In-trip location streams to the rider (`trip.location`); End finalizes fare.
- [ ] Rate-rider works once (`ALREADY_RATED` guarded); history paginates.
- [ ] Reconnect after a dropped socket restores the correct active-trip state.

---

## D5 — Earnings, wallet & payouts

**Goal:** The driver sees today/week/month earnings, a full wallet ledger, can close cash
trips, set a payout method, and withdraw — all money exact to the paise.

### Screens
- **Earnings dashboard** — today / this-week / this-month gross + net, trip count, simple bar trend.
- **Wallet** — balance + lifetime totals; **ledger** list (CREDIT/DEBIT, reason, `balanceAfter`), paginated.
- **Cash-collected action** — on a finished CASH trip, "Cash collected" debits commission+GST (idempotent).
- **Payout method** — UPI or BANK; masked account display; edit.
- **Request payout** — amount entry (≤ balance), confirm; `INSUFFICIENT_BALANCE` / `PAYOUT_METHOD_REQUIRED` handling.
- **Payouts list + detail** — status timeline.
- **Invoice viewer** — JSON line items + open PDF.

### Endpoints
`POST /trips/:id/payment/cash-collected` (⊕ idempotent) · `GET /drivers/me/wallet` ·
`/wallet/ledger` · `/earnings/today|this-week|this-month` · `GET/PUT /drivers/me/payout-method` ·
`POST /drivers/me/payouts/request` (⊕) · `GET /drivers/me/payouts` · `/payouts/:id` ·
`GET /trips/:id/invoice` · `/invoice.pdf`.

### Acceptance
- [ ] Earnings figures match backend to the paise across all three windows (IST boundaries).
- [ ] Cash-collected closes a CASH trip exactly once (idempotency-key reuse safe).
- [ ] Payout method saves and displays masked; withdrawal debits wallet + appears in payouts.
- [ ] `INSUFFICIENT_BALANCE` and `PAYOUT_METHOD_REQUIRED` show actionable copy.
- [ ] Invoice PDF opens.

---

## D6 — Carpool (scheduled trips) + chat

**Goal:** The driver posts a scheduled carpool trip, manages bookings, runs the trip day,
and chats 1:1 with booked riders.

### Screens
- **Post scheduled trip** — origin/destination (map + geocode), departure time, vehicle, total seats, price/seat, preferences (AC, gender), notes.
- **My scheduled trips** — list by status; edit (only OPEN + no bookings); cancel (refunds + notifies).
- **Bookings on a trip** — rider info, seats, pickup; start day → IN_PROGRESS; mark no-show; complete.
- **Chat threads** + **thread view** — 1:1, unread counts, live via WS.

### Endpoints / WS
`POST /scheduled-trips` · `GET /scheduled-trips/me` · `PATCH /scheduled-trips/:id` ·
`POST /scheduled-trips/:id/cancel|start|complete` · `GET /scheduled-trips/:id/bookings` ·
`POST /bookings/:id/no-show`. Chat: `POST /chats/messages` · `GET /chats/threads` ·
`/threads/:otherUserId/messages` · `POST /threads/:otherUserId/read`.
WS: `chat.message.received`.

### Acceptance
- [ ] Post a trip; it appears in search (verify via rider app / admin).
- [ ] Edit blocked once a booking exists; cancel refunds + notifies riders.
- [ ] Start → no-show → complete flow works; seat accounting correct.
- [ ] Chat delivers in real time; unread badges accurate; mark-read clears them.

---

## D7 — Notifications, safety & launch

**Goal:** Production hardening — FCM inbox, SOS, live-share, support, accessibility/perf
polish, and store submission.

### Screens
- **Notifications inbox** — list, unread badge, deep-link tap → target screen; mark one / all read.
- **SOS** — in-trip panic → SMS to emergency contacts + alert counterparty; confirm screen.
- **Share trip** — generate live-tracking link; list + revoke active shares.
- **Support** — open ticket, lost-item, my tickets + thread reply; FAQ / legal (terms, privacy) from `/content/*`.
- **Settings polish** — sessions, logout-all-others, account-delete request + cancel.

### Infra
- FCM register on launch (`POST /users/me/device-tokens`), unregister on logout.
- Full-screen-intent channel for trip offers (ties back to D4).
- Localization (en/bn/hi) finalized; dark theme audited; a11y labels; cold-start + battery-drain profiling.
- Store assets, privacy policy link, versioning, release flavors, crash reporting.

### Endpoints / WS
`POST/DELETE /users/me/device-tokens` · `GET /notifications` · `/unread-count` ·
`POST /notifications/:id/read` · `/read-all` · `POST /trips/:id/sos` · `/share` · `GET /trips/:id/shares` ·
`DELETE /trips/:id/share/:shareId` · `POST /support/tickets` · `/lost-item` · `GET /support/tickets/me` ·
`/tickets/:id` · `POST /tickets/:id/messages` · `GET /content/faq|articles/:slug|legal/:slug`.
WS: `notification.received`, `payment.succeeded|failed`.

### Acceptance
- [ ] FCM token registers on launch, unregisters on logout.
- [ ] Tapping a push deep-links to the right screen (incl. trip offer from cold start).
- [ ] SOS sends; share link works in a browser and revoke kills it.
- [ ] Support ticket round-trips; FAQ/legal render in all 3 locales.
- [ ] Dark mode + a11y pass; cold start < 3s on a mid Android; release APK/AAB built.

---

## 5. Definition of "sprint complete"

1. Every screen in the sprint is built and navigable.
2. Every listed endpoint is integrated against the **real** backend — no mocks left.
3. Critical paths have widget/integration tests (auth, KYC upload, go-online, trip lifecycle, payout).
4. Verified on ≥1 real Android device (Android 12+) and an iOS simulator.
5. A signed build (APK/AAB) is shared with the founder for demo.
6. New strings localized (en/bn/hi); no hard-coded colors/paddings outside the design system.

## 6. Cross-cutting / do-it-every-sprint

- Branch on `error.code`; keep a single `error.code → user message` map.
- `Idempotency-Key` on every money/state-changing POST (online, accept, cash-collected, payout, etc.).
- All money rendered from integer paise via one `formatPaise()` helper.
- WS is a notifier, **REST is the truth** — always reconcile after reconnect.
- Loading / empty / error states use the shared components — never a bare spinner.

## 7. Out of scope (driver app MVP)

Rider booking UI, Apple Pay/Wallet, in-app calling (use phone deep-link), biometric login,
tablet/Wear layouts, promo/referral UI, offline beyond queued pings + KYC drafts.
