# Auth Flows — Signup, Login, Logout (for the Flutter team)

> Exact API sequence for **signup**, **login**, **logout**, **token refresh** and
> **forgot-password**, with real request/response JSON. Field names are taken
> straight from the backend DTOs. Base URL for every path = `/api/v1`.

---

## ⚠️ Read this first — OTP is sent by Firebase, not by our backend

The backend does **not** send the SMS. Phone-OTP runs **client-side** through the
`firebase_auth` SDK. The flow is always:

1. App asks Firebase to send the OTP (`verifyPhoneNumber`) → Firebase SMSes the code.
2. User types the code → app calls `credential` / `signInWithCredential` → Firebase
   returns a **Firebase ID token** (`await firebaseUser.getIdToken()`).
3. App sends that **Firebase ID token** to our backend, which verifies it with the
   Firebase Admin SDK and issues **our** tokens.

Our `/auth/otp/send` and `/auth/signup/start` endpoints exist for **rate-limiting,
audit, and to hand back a ticket** — they do not deliver the SMS. So every OTP
screen needs the `firebase_auth` package wired up.

**Two kinds of "token" you'll handle** (see the bottom section for storage rules):

- **Firebase ID token** — produced by Firebase on the device, used **once** to prove
  the phone to our backend. Not ours, not stored.
- **`accessToken` + `refreshToken`** — **our** session tokens, returned by signup-
  complete / login / otp-verify. These are what you persist and send on requests.
- **`signupToken`** — a short-lived bridge token between "OTP verified" and "account
  created" (signup only). Throw it away after `signup/complete`.

---

## A. Signup (new user) — 3 backend calls + Firebase

```
[1] POST /auth/signup/start        → signupTicket
[F] Firebase verifyPhoneNumber + user enters OTP → firebaseIdToken
[2] POST /auth/signup/verify-otp   → signupToken
[3] POST /auth/signup/complete     → { accessToken, refreshToken, user }  ✅ logged in
```

### 1) Start signup
`POST /auth/signup/start`
```json
{ "phone": "+919876543210" }
```
Response → `{ "signupTicket": "sgt_…", "cooldownSeconds": 60 }`
Then trigger Firebase `verifyPhoneNumber(+919876543210)`.

### 2) Verify OTP
After the user enters the code and Firebase gives you `firebaseIdToken`:
`POST /auth/signup/verify-otp`
```json
{
  "signupTicket": "sgt_…",
  "firebaseIdToken": "<from firebase_auth>",
  "deviceInfo": { "model": "Pixel 8", "os": "Android 15", "userAgent": "rideshare/1.0.0 (Android)" }
}
```
Response → `{ "signupToken": "<10-min single-use>" }`

### 3) Complete signup (collect name + set a 6-digit password)
`POST /auth/signup/complete`
```json
{
  "signupToken": "<from step 2>",
  "firstName": "Rahul",
  "lastName": "Das",                      // optional
  "email": "rahul@example.com",           // optional
  "gender": "MALE",                       // optional: MALE | FEMALE | OTHER
  "password": "654321",                   // exactly 6 digits
  "passwordConfirm": "654321",
  "emergencyContactName": "Father",       // optional
  "emergencyContactPhone": "+919876543211", // optional, E.164
  "deviceInfo": { "model": "Pixel 8", "os": "Android 15" }
}
```
Response → the **auth payload** (see shape below). User is now signed in.

---

## B. Login (returning user) — password, no OTP

Daily login is the **6-digit password**, one call, no Firebase:

`POST /auth/login`
```json
{
  "phone": "+919876543210",
  "password": "654321",
  "deviceInfo": { "model": "Pixel 8", "os": "Android 15" }
}
```
Response → the **auth payload**. Wrong password → `401`.

### (Optional) Passwordless login via OTP
For an **existing** user who'd rather use OTP than a password:
```
[1] POST /auth/otp/send  { "phone": "+91…" }      → { status:"ACCEPTED", cooldownSeconds }
[F] Firebase verifyPhoneNumber + OTP              → firebaseIdToken
[2] POST /auth/otp/verify { "idToken": "<firebaseIdToken>", "deviceInfo": {…} } → auth payload
```

---

## C. The auth payload (returned by signup-complete / login / otp-verify)

```json
{
  "accessToken": "eyJ…",       // short-lived (~15 min) — Authorization: Bearer <accessToken>
  "refreshToken": "eyJ…",      // long-lived (~30 days) — used to refresh
  "expiresIn": 900,            // access token TTL in seconds
  "user": {
    "publicId": "usr_abc123",
    "phone": "+919876543210",
    "email": "rahul@example.com",
    "firstName": "Rahul",
    "lastName": "Das",
    "dob": null,
    "gender": "MALE",
    "avatarUrl": null,
    "roles": ["RIDER"],
    "status": "ACTIVE",
    "createdAt": "2026-06-05T12:34:56.000Z"
  }
}
```
(Remember the envelope: this object is under `response.data`.)

---

## D. Token refresh (keep the session alive)

Access token lasts ~15 min. When any authed call returns **`401` with
`error.code = "TOKEN_EXPIRED"`**, refresh once and retry the original request:

`POST /auth/refresh`
```json
{ "refreshToken": "<stored refresh token>" }
```
Response → a **new** `{ accessToken, refreshToken, expiresIn, user }`. Replace both
stored tokens (refresh tokens rotate — the old one is now invalid). If refresh
itself returns `401`, the session is dead → send the user back to login.

> Tip: implement this in a Dio interceptor (`onError` → refresh → retry), with a
> mutex so concurrent 401s trigger only one refresh.

---

## E. Logout

**This device:**
`POST /auth/logout`
```json
{ "refreshToken": "<this device's refresh token>" }
```
→ `204`. Then clear the stored tokens locally.

**All other devices (keep this one):**
`POST /auth/logout/all-others`
```json
{ "refreshToken": "<this device's refresh token — the one to keep>" }
```
→ `{ "revoked": 3 }`

**See / manage sessions** (Settings → Devices):
- `GET /users/me/sessions` → list (`id` = `ses_*`, `device`, `current`, `createdAt`, `expiresAt`)
- `DELETE /users/me/sessions/:id` → revoke one (`204`)

---

## F. Forgot / reset / change password

**Forgot (reset via OTP):**
```
[1] POST /auth/password/forgot/request { "phone": "+91…" }   → { resetTicket }
[F] Firebase verifyPhoneNumber + OTP                          → firebaseIdToken
[2] POST /auth/password/forgot/reset
    { "resetTicket": "rst_…", "firebaseIdToken": "<…>",
      "newPassword": "123456", "newPasswordConfirm": "123456" }
    → auth payload (all old sessions revoked, fresh tokens returned)
```

**Change (while logged in):**
`POST /auth/password/change`
```json
{ "currentPassword": "654321", "newPassword": "123456", "newPasswordConfirm": "123456" }
```
→ auth payload (revokes other sessions, returns fresh tokens).

**Set (OTP-only account adding a password the first time):**
`POST /auth/password/set` → `{ "newPassword": "123456", "newPasswordConfirm": "123456" }`

---

## G. Token storage & client rules (please follow)

- **`refreshToken`** → store in **secure storage** (`flutter_secure_storage` /
  Keychain / Keystore). Never in plain SharedPreferences.
- **`accessToken`** → keep in memory (or secure storage); attach as
  `Authorization: Bearer <accessToken>` on every authed request.
- **`signupToken` / Firebase ID token** → use immediately, then discard. Don't persist.
- On app launch: if a `refreshToken` exists, call `/auth/refresh` to get a live
  access token before hitting other endpoints; on failure, route to login.
- Send `deviceInfo` (`{ model, os, userAgent }`) on signup/login/verify so the
  Sessions screen shows meaningful device names.
- After login, register the FCM token: `POST /users/me/device-tokens`
  `{ fcmToken, platform }`. On logout, `DELETE /users/me/device-tokens { fcmToken }`.

---

## H. Quick reference

| Step | Method & path | Body | Returns |
|---|---|---|---|
| Signup ① | `POST /auth/signup/start` | `phone` | `signupTicket` |
| Signup ② | `POST /auth/signup/verify-otp` | `signupTicket`, `firebaseIdToken`, `deviceInfo?` | `signupToken` |
| Signup ③ | `POST /auth/signup/complete` | `signupToken`, `firstName`, `password`, `passwordConfirm`, …opt | auth payload |
| Login | `POST /auth/login` | `phone`, `password`, `deviceInfo?` | auth payload |
| OTP login ① | `POST /auth/otp/send` | `phone` | `{ status, cooldownSeconds }` |
| OTP login ② | `POST /auth/otp/verify` | `idToken`(firebase), `deviceInfo?` | auth payload |
| Refresh | `POST /auth/refresh` | `refreshToken` | auth payload |
| Logout | `POST /auth/logout` | `refreshToken` | `204` |
| Logout others | `POST /auth/logout/all-others` | `refreshToken` (keep) | `{ revoked }` |
| Forgot ① | `POST /auth/password/forgot/request` | `phone` | `resetTicket` |
| Forgot ② | `POST /auth/password/forgot/reset` | `resetTicket`, `firebaseIdToken`, `newPassword`, `newPasswordConfirm` | auth payload |
| Change pw | `POST /auth/password/change` | `currentPassword`, `newPassword`, `newPasswordConfirm` | auth payload |
| Me | `GET /auth/me` | — | current user |

> Live request/response schemas: **Swagger at `/docs`** (always matches the code).
> Firebase client setup for OTP: see `docs/` Firebase setup guide.
