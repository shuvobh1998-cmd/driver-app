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

## ⚠️ Firebase OTP is gated
Per the backend handoff, the OTP SMS is sent **client-side by Firebase**
(`firebase_auth`), and the resulting Firebase ID token is forwarded to the
backend. Signup and forgot-password depend on this step.

`firebase_auth` is **not yet in `pubspec.yaml`** and there is **no
`google-services.json`**, so that step is abstracted behind
`PhoneVerifier` (`data/phone_verifier.dart`). The default
`UnconfiguredPhoneVerifier` fails cleanly with
`PHONE_VERIFICATION_UNAVAILABLE`. The signup/forgot **UI is fully built and
wired**; to enable them:
1. Add `firebase_auth` to `pubspec.yaml` and a Firebase project +
   `google-services.json` / `firebase_options.dart`.
2. Implement `PhoneVerifier` with `firebase_auth` (`verifyPhoneNumber` →
   `signInWithCredential` → `getIdToken()`).
3. Override `phoneVerifierProvider` in the bootstrap.

See `docs/DRIVER_APP_SPRINT_PLAN.md` and `others/mobile/AUTH_FLOWS.md`.
