# Flutter Developer Handoff

> Share this doc with the 2 Flutter developers. Single page to get started.

## URLs (after backend deploy)

| Item               | URL                                                      |
| ------------------ | -------------------------------------------------------- |
| API base           | `https://rideshare-backend-dev.fly.dev/api/v1`           |
| Swagger UI         | `https://rideshare-backend-dev.fly.dev/docs`             |
| Health check       | `https://rideshare-backend-dev.fly.dev/api/v1/health`    |
| WebSocket          | `wss://rideshare-backend-dev.fly.dev`                    |
| Admin panel        | `https://rideshare-admin-dev.vercel.app` (when deployed) |
| Postman collection | shared link — see Slack                                  |

## Test credentials (dev only)

- **Test phone:** `+919999999999`
- **Test OTP:** `123456` (Firebase test number — works without real SMS)
- **Test password (after signup):** `654321`
- **Admin:** `admin@example.com` / `ChangeMe!2026`

## What to read first

1. **[MOBILE_API_PLAN.md](MOBILE_API_PLAN.md)** — every mobile screen mapped to endpoints + WebSocket events
2. **[API_CONVENTIONS.md](API_CONVENTIONS.md)** — URL, error, auth, pagination rules
3. Swagger UI — live request/response shapes

## Non-negotiable conventions

- All money in integer **paise** (₹100 = 10000) — never floats
- All locations as `{lat, lng}` objects — never `[lng, lat]` arrays
- All timestamps ISO 8601 UTC strings
- `Idempotency-Key` header on every money/state-changing POST
- Error switch on `error.code`, not `error.message`
- WebSocket auth: JWT in connect query `?token=...`

## Auth flow (what your app implements)

### Signup

1. User enters phone → `POST /auth/signup/start` → get `signupTicket`
2. SMS OTP arrives → `POST /auth/signup/verify-otp` → get `signupToken` (10 min)
3. User fills name, email, gender, password, retype, emergency contact (optional) → `POST /auth/signup/complete` → get `{accessToken, refreshToken, user}`
4. Store `refreshToken` in **secure storage** (flutter_secure_storage)
5. Store `accessToken` in memory
6. Navigate to home

### Login (returning user)

1. User enters phone + password → `POST /auth/login` → `{accessToken, refreshToken, user}`
2. Same storage pattern

### Token auto-refresh (interceptor)

1. On any 401 with `TOKEN_EXPIRED` → call `POST /auth/refresh` with refresh token
2. Replace tokens, retry original request
3. If refresh fails → clear storage, kick to login

### Logout

1. `POST /auth/logout` (revokes server-side refresh token)
2. Clear secure storage
3. Disconnect WebSocket
4. Unregister FCM: `DELETE /users/me/device-tokens`

## WebSocket integration

### Connect

```dart
final socket = IO.io('wss://rideshare-backend-dev.fly.dev', <String, dynamic>{
  'transports': ['websocket'],
  'query': {'token': accessToken},
  'autoConnect': true,
  'reconnection': true,
  'reconnectionDelay': 1000,
  'reconnectionDelayMax': 30000,
});
```

### Subscribe per trip

```dart
socket.emit('trip:join', {'tripId': tripId});
socket.on('driver.location.updated', (data) => updateMapMarker(data));
socket.on('trip.status.changed', (data) => updateTripState(data));
```

See [MOBILE_API_PLAN.md](MOBILE_API_PLAN.md) section "WebSocket reference" for all events.

## File uploads (KYC, vehicle photos, avatar)

- `Content-Type: multipart/form-data`
- Field name: `file`
- Max 5MB
- Accepted: `image/jpeg`, `image/png`, `application/pdf`
- Use `dio` package — easiest multipart in Flutter

## Recommended Flutter packages

| Need                     | Package                                                         |
| ------------------------ | --------------------------------------------------------------- |
| HTTP client              | `dio`                                                           |
| Secure storage           | `flutter_secure_storage`                                        |
| State management         | `riverpod` or `bloc`                                            |
| Map                      | `flutter_map` (free, OSM) or `google_maps_flutter` (paid quota) |
| WebSocket                | `socket_io_client`                                              |
| Payments                 | `razorpay_flutter`                                              |
| FCM push                 | `firebase_messaging`                                            |
| Phone auth               | Not needed — backend handles OTP via Firebase Admin             |
| Image picker             | `image_picker`                                                  |
| Pin entry (OTP/password) | `pin_code_fields`                                               |

## Mock server strategy (while backend deploys)

Use Postman's mock server feature OR `prism` CLI against the Swagger JSON:

```bash
npm install -g @stoplight/prism-cli
prism mock https://rideshare-backend-dev.fly.dev/docs-json -p 4010
```

Then point your dev app to `http://10.0.2.2:4010/api/v1` (Android emulator) or `http://localhost:4010/api/v1` (iOS sim).

## Build order

Two parallel tracks (one dev each):

**Dev A — Onboarding + Rider booking flow**

1. Splash + token check
2. Login + signup (Sprint 5 endpoints)
3. Rider home + map
4. Address autocomplete
5. Fare estimate per vehicle type
6. Request ride
7. Trip tracking (WS) — mocked until Sprint 7 lands
8. Trip history

**Dev B — Driver flow + KYC**

1. KYC document upload
2. Vehicle registration
3. Driver home + online/offline toggle
4. Location ping background service
5. Trip offer notification + accept screen
6. Trip lifecycle screens (mocked until Sprint 7 lands)
7. Earnings + payout screens (mocked until Sprint 8 lands)

Then converge for:

- Scheduled carpool flow (Sprint 9)
- Notifications + support (Sprint 10)

## Reporting bugs / asking for endpoints

- Slack channel: `#rideshare-backend`
- Bugs: GitHub Issues with `mobile` label
- New endpoint requests: open issue with screen mockup + desired payload

## What's not in MVP (don't build)

- iOS-specific Apple Pay / CallKit
- In-app calling (use phone number deep link)
- Promo codes / referrals
- Multi-language (English only for MVP)
- Dark mode (system follows OS)
- Offline mode beyond cached map tiles

## Questions

If anything in this doc or in MOBILE_API_PLAN.md is unclear, ask in Slack before implementing — wrong assumption is more expensive than asking.
