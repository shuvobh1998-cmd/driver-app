# auth

D1 — Foundation + Auth: signup, OTP, login, session persistence, profile.

Layers:
- `data/` — models (`AuthUser`, `UserProfile`, `AuthResponse`, `AuthSession`,
  `DeviceInfo`), `AuthApi` (raw `/auth/*` transport), `AuthRepository` (token
  persistence + session restore), `phone_verifier.dart`.
- `presentation/` — `AuthController` (session state) + screens (splash, login,
  signup flow, forgot-password).

## Implemented (against the live dev backend)
- **Login** (phone + 6-digit PIN) — fully working end-to-end.
- Session restore on launch (refresh-token → `/auth/refresh` → `/auth/me`),
  transparent 401 `TOKEN_EXPIRED` refresh + retry, forced sign-out on refresh
  failure (`core/network/auth_token_service.dart`).
- Profile view/edit + avatar, settings shell (see `features/settings`).

## Firebase OTP (signup + forgot-password)
Per the backend handoff, the OTP SMS is sent **client-side by Firebase**
(`firebase_auth`); the resulting Firebase ID token is forwarded to the backend.
That step lives behind the `PhoneVerifier` interface (`data/phone_verifier.dart`).

- **dev flavor:** wired. `firebase_auth` + `android/app/google-services.json`
  (project `rideshare-dev-df265`, package `com.driverapp.driver_app.dev`) are
  configured; `bootstrap` calls `Firebase.initializeApp()` and overrides
  `phoneVerifierProvider` with `FirebasePhoneVerifier`. Use a **Firebase test
  number** (Auth → Sign-in method → Phone → test numbers) to sign up without
  real SMS.
- **staging/prod:** not registered yet. `Firebase.initializeApp()` is
  best-effort in bootstrap — those flavors fall back to
  `UnconfiguredPhoneVerifier`, which fails cleanly with
  `PHONE_VERIFICATION_UNAVAILABLE`. Register the staging/prod package names and
  add their `google-services.json` to enable OTP there.

Each developer/test device's **debug SHA-1** must be added to the Firebase
Android app for phone auth to work on that machine.

See `docs/DRIVER_APP_SPRINT_PLAN.md` and `others/mobile/AUTH_FLOWS.md`.
