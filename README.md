# Driver App

A standalone Flutter app **for drivers only** (separate binary from the rider
app) on the ride-sharing platform. A driver signs up, submits KYC + a vehicle,
gets approved, goes online, runs trips, and gets paid.

The full product/sprint plan lives in
[`docs/DRIVER_APP_SPRINT_PLAN.md`](docs/DRIVER_APP_SPRINT_PLAN.md). This README
covers running the project; **Sprint 0 (scaffolding) is complete** — the app
compiles in all three flavors and shows a themed placeholder screen.

## Requirements

- Flutter `3.44.x` (Dart `3.12.x`) — see `FLUTTER_VERSION` in CI.
- Android SDK (for APK builds). Xcode for iOS.

## First-time setup

```sh
make bootstrap        # flutter pub get + all codegen
git config core.hooksPath .githooks   # enable the format+analyze pre-commit hook
```

Generated code (`lib/gen/`, `lib/l10n/gen/`, `*.g.dart`) is **gitignored** and
recreated by codegen — always run `make codegen` after a fresh clone or a pull
that touches the API spec, `.arb` files, or drift/JSON models.

## Build flavors

Three flavors — `dev` / `staging` / `prod` — selected by entrypoint +
`--flavor`, with the API/WS base URLs supplied via `--dart-define` (per-flavor
fallbacks exist in `AppConfig`). All three install side by side.

```sh
make run-dev          # or run-staging / run-prod
```

Equivalent raw command:

```sh
flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=ENV=dev \
  --dart-define=API_BASE_URL=https://api.dev.example.com \
  --dart-define=WS_BASE_URL=https://ws.dev.example.com
```

Build a debug APK:

```sh
make apk              # flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

> iOS flavor schemes (Runner Dev/Staging/Prod) are set up in Xcode in D1; the
> Android flavors are wired here.

## Release build (store)

Release signing reads `android/key.properties` (gitignored). Without it,
release builds fall back to debug signing so CI and dev machines still build.
To produce a store bundle:

1. Generate an upload keystore (kept out of the repo) and copy
   `android/key.properties.example` → `android/key.properties`, filling in the
   keystore path + passwords.
2. Build the signed Android App Bundle:

```sh
flutter build appbundle --flavor prod -t lib/main_prod.dart
# → build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

The brand launcher icon + native splash are generated from `assets/branding/`
via `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.

## Codegen

| Command | What it does |
| --- | --- |
| `make models` | OpenAPI DTOs/clients from `api/openapi.yaml` → `lib/gen/` (swagger_parser). |
| `make l10n` | `AppLocalizations` delegate from `lib/l10n/*.arb` (en/bn/hi). |
| `make codegen` | All of the above + `build_runner` (drift + json_serializable + retrofit). |
| `make watch` | `build_runner watch`. |

Point `swagger_parser.yaml` at the live backend spec (`schema_url`) before D1.

## Quality

```sh
make format           # dart format lib test
make analyze          # flutter analyze (must be clean)
make test             # flutter test
```

CI (`.github/workflows/ci.yml`) runs codegen → format check → analyze → test on
every push, then builds + uploads the dev debug APK.

## Project structure

Feature-first. Cross-cutting layers up top, one folder per feature below.

```
lib/
  app/            MaterialApp.router root, go_router config + guards, bootstrap
  core/           config, network (dio + interceptors), storage (secure + drift),
                  websocket, location, push, error
  design_system/  tokens (colors/typography/spacing/theme) + reusable widgets
  shared/         formatPaise(), date helpers, validators
  features/       auth, onboarding_kyc, driver_home, trips, earnings, carpool,
                  notifications, settings  (each: data/ domain/ presentation/)
  l10n/           app_en.arb, app_bn.arb, app_hi.arb
  gen/            OpenAPI-generated DTOs (gitignored)
```

## Conventions (non-negotiable)

- Money is integer **paise** end to end; render only via `formatPaise()`.
- Locations as `{lat,lng}`; timestamps ISO-8601 **UTC** on the wire.
- `Idempotency-Key` on every money/state-changing POST (handled by the client).
- Branch on `error.code`, never message text; map codes in `core/error`.
- WebSocket is a notifier — **REST is the source of truth**; reconcile on reconnect.
- No hand-rolled colors/paddings outside `design_system/`; no bare spinners.
