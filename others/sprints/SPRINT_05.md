# Sprint 5 — Mobile Auth & Onboarding Completion

> **Duration:** 2 weeks
> **Theme:** Phone+password auth model, signup completion flow, missing profile fields, app config endpoint — everything Flutter devs need to build the onboarding screens you described.

## Goal

A Flutter developer can build the entire onboarding/login/profile flow end-to-end:

1. Splash → check session
2. Phone + 6-digit password login
3. Signup: phone → OTP → name + email + gender + password + retype + emergency contact (optional) → JWT
4. Forgot password via OTP
5. App boots with `GET /app/config` to know vehicle types, support phone, terms URL, min app version

All without depending on any future sprint.

## Why this sprint

Current Sprint 1 ships OTP-only login. The mobile UX you described uses **phone + 6-digit password** (faster daily login), with OTP reserved for first-time signup and password reset. This is the standard Indian ride-app pattern (Rapido, Uber India, Ola). Adding it now unblocks Flutter onboarding work before Sprint 7 (trips) lands.

## Features

### 1. Schema additions

Migration `0011_user_password_and_profile_fields`:

- `users` table additions:
  - `password_hash` TEXT NULL (argon2id, NULL = user signed up via OTP only)
  - `password_set_at` TIMESTAMPTZ NULL
  - `gender` VARCHAR(10) NULL (`MALE`, `FEMALE`, `OTHER`, `PREFER_NOT_TO_SAY`)
  - `date_of_birth` DATE NULL
  - `emergency_contact_name` VARCHAR(100) NULL
  - `emergency_contact_phone` VARCHAR(15) NULL
  - `email_verified_at` TIMESTAMPTZ NULL
- Index: `users(phone)` already unique

### 2. Signup flow (3 endpoints)

Multi-step to prevent abuse + give the app proper UX states:

**`POST /api/v1/auth/signup/start`**

- Body: `{ phone }`
- If phone exists → `409 PHONE_ALREADY_REGISTERED`
- Sends OTP via Firebase
- Returns: `{ signupTicket: "<opaque-id>", expiresInSec: 300 }`
- `signupTicket` is a short-lived Redis key holding `{phone, otpHash}`

**`POST /api/v1/auth/signup/verify-otp`**

- Body: `{ signupTicket, otp }`
- Validates OTP against the ticket
- On success: returns `signupToken` (JWT-like, 10 min TTL, single-use, scope=signup-complete)
- Errors: `OTP_INVALID`, `OTP_EXPIRED`, `SIGNUP_TICKET_INVALID`

**`POST /api/v1/auth/signup/complete`**

- Body:
  ```json
  {
    "signupToken": "...",
    "firstName": "Rahul",
    "lastName": "Das",
    "email": "rahul@example.com",
    "gender": "MALE",
    "password": "654321",
    "passwordConfirm": "654321",
    "emergencyContactName": "Father",
    "emergencyContactPhone": "+919876543210"
  }
  ```
- Validates: password 6+ digits, password === passwordConfirm, email format, phone format
- Creates `users` row with `roles: ['RIDER']` by default
- Hashes password with argon2id
- Returns: `{ accessToken, refreshToken, user }` (logs them in)
- Errors: `SIGNUP_TOKEN_EXPIRED`, `VALIDATION_ERROR`, `EMAIL_ALREADY_USED`

### 3. Password login

**`POST /api/v1/auth/login`**

- Body: `{ phone, password }`
- Verifies argon2 hash
- Returns: `{ accessToken, refreshToken, user }`
- Errors: `INVALID_CREDENTIALS` (don't reveal which one is wrong), `ACCOUNT_SUSPENDED`, `PASSWORD_NOT_SET` (user signed up OTP-only — prompt to set password)
- Rate limit: 5 attempts per phone per 5 min → `RATE_LIMITED`

### 4. Forgot password

**`POST /api/v1/auth/password/forgot/request`**

- Body: `{ phone }`
- Always returns 200 even if phone doesn't exist (don't leak who's registered)
- If phone exists, sends OTP
- Returns: `{ resetTicket, expiresInSec: 300 }`

**`POST /api/v1/auth/password/forgot/reset`**

- Body: `{ resetTicket, otp, newPassword, newPasswordConfirm }`
- Validates OTP, updates `password_hash`, revokes ALL refresh tokens for this user
- Returns: `{ accessToken, refreshToken, user }` (auto-logs in)

### 5. Change password (authenticated)

**`POST /api/v1/auth/password/change`**

- Body: `{ currentPassword, newPassword, newPasswordConfirm }`
- Verifies current password, updates hash, revokes all OTHER refresh tokens (keep current session)

### 6. Set password (for OTP-only users)

**`POST /api/v1/auth/password/set`**

- Auth required
- Body: `{ newPassword, newPasswordConfirm }`
- Only allowed if `password_hash IS NULL`
- For migrating existing OTP-only users to password

### 7. Upgrade rider → driver

**`POST /api/v1/users/me/upgrade-to-driver`**

- Auth required
- Adds `DRIVER` role to user's `roles` array if not present
- Returns updated user
- Note: KYC + vehicle still required separately (Sprint 2 endpoints)

### 8. App config endpoint

**`GET /api/v1/app/config`**

- Public (no auth)
- Returns:
  ```json
  {
    "vehicleTypes": [
      { "code": "BIKE", "label": "Bike", "iconUrl": "..." },
      { "code": "AUTO", "label": "Auto", "iconUrl": "..." },
      { "code": "CNG", "label": "CNG", "iconUrl": "..." },
      { "code": "CAR", "label": "Car", "iconUrl": "..." }
    ],
    "supportPhone": "+919999999999",
    "supportEmail": "support@example.com",
    "termsUrl": "https://example.com/terms",
    "privacyUrl": "https://example.com/privacy",
    "city": "Kolkata",
    "currency": "INR",
    "minSupportedVersion": { "android": "1.0.0", "ios": "1.0.0" },
    "latestVersion": { "android": "1.0.0", "ios": "1.0.0" },
    "forceUpdate": false
  }
  ```
- Backed by env vars + a `app_config` Postgres table (admin can edit later)

### 9. Profile field exposure

Ensure existing `GET /api/v1/users/me/profile` and `PATCH /api/v1/users/me/profile` return + accept all new fields:

- `gender`, `dateOfBirth`, `emergencyContactName`, `emergencyContactPhone`
- `email` already there

### 10. Admin panel updates

- `/users/[id]` detail page: show password-set status, emergency contact, gender, DOB
- `/app-config` page: edit support phone/email, terms URL, force-update flag

## API endpoints delivered (full list)

| Method | Path                                   | Auth         | Purpose                             |
| ------ | -------------------------------------- | ------------ | ----------------------------------- |
| POST   | `/api/v1/auth/signup/start`            | none         | Begin signup, send OTP              |
| POST   | `/api/v1/auth/signup/verify-otp`       | none         | Verify signup OTP                   |
| POST   | `/api/v1/auth/signup/complete`         | signup-token | Finish signup, get JWT              |
| POST   | `/api/v1/auth/login`                   | none         | Phone + password login              |
| POST   | `/api/v1/auth/password/forgot/request` | none         | Forgot password OTP                 |
| POST   | `/api/v1/auth/password/forgot/reset`   | reset-ticket | Reset password with OTP             |
| POST   | `/api/v1/auth/password/change`         | bearer       | Change password                     |
| POST   | `/api/v1/auth/password/set`            | bearer       | Set first password (OTP-only users) |
| POST   | `/api/v1/users/me/upgrade-to-driver`   | rider        | Add DRIVER role                     |
| GET    | `/api/v1/app/config`                   | none         | App bootstrap config                |
| GET    | `/api/v1/admin/app-config`             | admin        | Read config (admin)                 |
| PATCH  | `/api/v1/admin/app-config`             | admin        | Update config                       |

## DB migrations

1. `0011_user_password_and_profile_fields` — `users` additions
2. `0012_app_config` — `app_config` key/value table

## Admin panel pages

| Page                     | Purpose                                         |
| ------------------------ | ----------------------------------------------- |
| `/app-config`            | Edit support phone, terms, force-update flag    |
| `/users/[id]` (enhanced) | Show password status, gender, emergency contact |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + Swagger + Postman. No Flutter code from us.

**Endpoints shipped** — full list in the table above. Highlights:

- Signup: `POST /api/v1/auth/signup/start` → `/verify-otp` → `/complete` (3-step)
- Login: `POST /api/v1/auth/login` (phone + 6-digit password)
- Forgot/reset password: `POST /api/v1/auth/password/forgot/request` → `/reset`
- Change/set password: `POST /api/v1/auth/password/{change,set}`
- Role upgrade: `POST /api/v1/users/me/upgrade-to-driver`
- App boot: `GET /api/v1/app/config` (public — no auth)

**WebSocket events:** none.

**Validation rules Flutter must match:**

- Phone: E.164, `+91` for India, 10 digits after country code
- Password: exactly 6 digits (numeric only) for MVP — keypad-friendly
- OTP: 6 digits, 5 min TTL
- Email: standard format
- Name: 1–100 chars
- Rate limits: 5 login attempts per phone per 5 min, then `RATE_LIMITED`

**Artifacts:**

- Postman collection: `docs/postman/sprint-05.json`
- See [`docs/mobile/MOBILE_API_PLAN.md`](../mobile/MOBILE_API_PLAN.md) screens A1–A10 and B11–B19 for screen→endpoint mapping

**Unblocks mobile sprint M02 (auth/onboarding)** — full signup flow, password login, forgot password, change password, app bootstrap. See [`docs/mobile/sprints/MOBILE_SPRINT_02.md`](../mobile/sprints/MOBILE_SPRINT_02.md).

## Demo checklist

- [ ] App config returns vehicle types — Flutter renders chips
- [ ] Brand new phone signs up → completes profile → lands on home logged in
- [ ] Same user logs out → logs back in with phone + password
- [ ] Wrong password 6 times → rate-limited
- [ ] Forgot password → OTP → new password → can log in
- [ ] Change password while logged in → other devices kicked out
- [ ] OTP-only legacy user → `POST /auth/password/set` → can now use password login
- [ ] Rider upgrades to driver → DRIVER role added → can now access driver endpoints

## Definition of Done

- [ ] All endpoints in table above functional and Swagger-documented
- [ ] argon2id hashing (cost params tuned for Fly.io shared-cpu-1x: m=19MB, t=2, p=1)
- [ ] Rate limiting on `/login` and `/password/forgot/*`
- [ ] OTP never leaks in API response (only in SMS)
- [ ] Refresh token revocation on password change/reset
- [ ] e2e: signup → login → change password → forgot password → reset flow
- [ ] Git tag `v0.5.0-sprint-5`

## Git plan

- `feature/sprint-5-schema` — migration + Prisma model updates
- `feature/sprint-5-signup-flow` — 3-step signup
- `feature/sprint-5-password-login` — login endpoint
- `feature/sprint-5-forgot-password` — request + reset
- `feature/sprint-5-change-set-password` — change + set
- `feature/sprint-5-upgrade-to-driver` — role upgrade
- `feature/sprint-5-app-config` — public + admin endpoints
- `feature/sprint-5-admin-pages` — app config + enhanced user detail

## Status

- [x] Backend auth + app-config delivered (mobile-facing API). Admin pages (§10) carried over.

## Delivered

- 3-step signup (`/auth/signup/{start,verify-otp,complete}`), phone+password
  `/auth/login`, forgot (`/auth/password/forgot/{request,reset}`), `/auth/password/{change,set}`.
- `POST /users/me/upgrade-to-driver` (idempotent DRIVER-role add).
- Public `GET /app/config` (env-backed).
- Profile fields exposed on `GET`/`PATCH /users/me/profile`: emergency contact +
  `passwordSet`/`emailVerified` flags.
- argon2id hashing (m=19MB, t=2, p=1); refresh-token revocation on change/reset.
- 244 backend unit tests green.

## Carryover

- Admin panel pages (`/app-config` editor, enhanced `/users/[id]`) — feature §10.
- Admin `GET`/`PATCH /api/v1/admin/app-config` — deferred with the admin pages.
- `app_config` DB table (migration `0012` in the original plan): **not built** —
  config is env-backed for now; add the table when the admin editor lands.

## Notes / Blockers

- **Migration numbering:** the plan named `0011`/`0012`, but those numbers were
  already taken by Sprint-4 trip migrations. Schema additions shipped as
  `0015_user_password_profile_fields`. The `email_verified_at` column is included.
- **OTP design:** Firebase phone auth is client-side, and there is no backend SMS
  provider, so the backend cannot store/verify a raw OTP. `signup/verify-otp` and
  `password/forgot/reset` accept a verified **`firebaseIdToken`** instead of a raw
  `otp`, gated by a Redis ticket. See [`docs/mobile/sprints/MOBILE_SPRINT_01.md`](../mobile/sprints/MOBILE_SPRINT_01.md) Notes.
