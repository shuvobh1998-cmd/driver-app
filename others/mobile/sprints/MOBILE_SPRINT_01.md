# Mobile Sprint M01 — Setup, Auth, Profile

> **Duration:** 2 weeks
> **Goal:** User can install the APK, sign up with phone+OTP+password, log in next day with phone+password, see their profile, edit fields, and pull the app config on launch.

## Scope

### Project setup

- Flutter project init (target Android 12+ and iOS 14+)
- Folder structure per [`../README.md`](../README.md)
- Dependencies: `dio`, `riverpod` (or `bloc`), `go_router`, `flutter_secure_storage`, `pin_code_fields`, `flutter_form_builder`
- Theme (light + dark), Material 3
- Routing skeleton
- Env config: `flavors` for dev / staging / prod (different API base URLs)
- Logging interceptor + Sentry init
- API client: dio + auth interceptor + 401 auto-refresh

### Screens

- Splash → check refresh token → home or login
- Phone entry (signup or login disambiguation)
- OTP entry (6-digit pin)
- Profile setup (name, email, gender dropdown, password, retype, emergency contact)
- Login (phone + 6-digit password)
- Forgot password — request OTP
- Forgot password — reset (OTP + new password + retype)
- Home shell (empty for now, sidebar drawer with logout)
- Profile view + edit
- Change password

### App bootstrap

- On launch, call `GET /api/v1/app/config`, cache 6h locally
- If `forceUpdate: true` → blocking update screen
- Use `vehicleTypes` in later sprints for booking screen

## Endpoints integrated

- `GET /api/v1/app/config`
- `POST /api/v1/auth/signup/start`
- `POST /api/v1/auth/signup/verify-otp`
- `POST /api/v1/auth/signup/complete`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/password/forgot/request`
- `POST /api/v1/auth/password/forgot/reset`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `GET /api/v1/users/me/profile`
- `PATCH /api/v1/users/me/profile`
- `POST /api/v1/users/me/avatar`
- `POST /api/v1/auth/password/change`

## Acceptance

- [ ] New user signup end-to-end (test phone + Firebase test OTP `123456`)
- [ ] Logout + login back with password
- [ ] Forgot password flow works
- [ ] Profile edit persists
- [ ] App config cached and used (vehicle types ready for next sprint)
- [ ] Force-update flag forces blocking screen
- [ ] Tested on real Android phone + iOS Simulator
- [ ] APK shared with founder

## Out of scope (M01)

- Driver-specific anything (M03)
- Maps (M02)
- Notifications (M08)
- Biometric login

## Status

- [x] Backend API delivered (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable for M01 = the backend endpoints + Swagger the Flutter team consumes.
> No Flutter code from us (per the task note). All endpoints live under `/api/v1`.

**App bootstrap**

- `GET /app/config` — public; vehicle types, support contacts, legal URLs,
  languages, Razorpay key id, min/latest versions, `forceUpdate`. Env-backed
  (`APP_*` vars) with dev defaults. App caches 6h.

**Auth (phone + 6-digit password)**

- `POST /auth/signup/start` → `signup/verify-otp` → `signup/complete` (3-step).
- `POST /auth/login` — phone + password, 5-fail/5-min rate limit.
- `POST /auth/password/forgot/request` → `password/forgot/reset` (no-leak ticket).
- `POST /auth/password/change` and `POST /auth/password/set`.
- Existing `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me` unchanged.

**Profile**

- `GET`/`PATCH /users/me/profile` now expose + accept `emergencyContactName`,
  `emergencyContactPhone`, and read-only `passwordSet` + `emailVerified` flags.
- `POST /users/me/avatar` unchanged.
- `POST /users/me/upgrade-to-driver` adds the DRIVER role (idempotent).

**Schema:** migration `0015_user_password_profile_fields` (`password_set_at`,
`emergency_contact_name/phone`, `email_verified_at`).

**Tests:** 244 backend unit tests green (30 in `auth.service.spec.ts`).

## Notes

**OTP is verified via Firebase, not a backend-stored code.** The locked stack uses
Firebase phone auth, which runs **client-side** (the Flutter `firebase_auth` SDK
sends + collects the SMS OTP and returns a Firebase **ID token**). There is no SMS
provider on the backend, so the backend cannot send or verify a raw 6-digit OTP.
Therefore:

- `signup/start` and `password/forgot/request` return a **ticket**; the Flutter
  client triggers the Firebase OTP SMS itself (in parallel).
- `signup/verify-otp` and `password/forgot/reset` take a **`firebaseIdToken`**
  (not a raw `otp`). The backend verifies it via the Firebase Admin SDK and
  confirms the phone matches the ticket. Test phone + Firebase test OTP `123456`
  still works end-to-end through the Firebase client SDK.

This is the only buildable design given the stack; the placeholder `otp` field in
earlier drafts is superseded by `firebaseIdToken`. Swagger (`/docs`) is authoritative.
