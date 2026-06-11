# Sprint 2 — End-to-End Testing Guide

> Exercise every Sprint 2 feature against your local backend + admin panel.
> Assumes Sprint 1's [TESTING_GUIDE.md](TESTING_GUIDE.md) is complete (backend
> boots, admin login works, you have a Firebase ID token for a rider).
> Estimate: 25–35 min.

---

## TL;DR — what you're going to do

1. Bring the new schema in (4 migrations land at once: `0002`…`0005`).
2. Add the new env vars and restart.
3. Sign in as a rider, fill out the user profile, upload an avatar.
4. Become a driver: create driver profile → upload KYC docs → register a vehicle + photo.
5. Register an FCM device token (so push works later).
6. Log into the admin panel, find the driver in `/drivers`, approve KYC, approve the vehicle.
7. Verify the driver received a push (or that the backend log shows the FCM call).
8. Try the rejection paths.

You'll need: `curl` (or Postman), one of the rider's Firebase ID tokens, a
PNG/JPEG to use as a fake KYC doc, and your admin login from Sprint 1.

---

## 1. Pull the new schema

```bash
cd backend
pnpm prisma:migrate:deploy
```

> **Use the `prisma:` scripts**, not the raw `prisma` CLI. The scripts wrap
> Prisma with `dotenv-cli` so they pick up `.env.local`; the raw CLI only reads
> `.env` and will error out with `Environment variable not found: DIRECT_URL`.

This applies `0002_user_profile_fields`, `0003_driver_profiles_and_kyc`,
`0004_vehicles`, `0005_device_tokens`. You can confirm with:

```bash
pnpm prisma:studio
```

You should now see four new tables (`driver_profiles`, `kyc_documents`,
`vehicles`, `device_tokens`) plus three new columns on `users` (`dob`,
`gender`, `avatar_url`).

---

## 2. Add the Sprint 2 env vars

Open `backend/.env.local` and add these. Defaults are fine for local dev — you
only **must** change them when going to a real environment.

```bash
# Sprint 2 Feature 1: avatar upload public URL builder
PUBLIC_BASE_URL=http://localhost:3000
STORAGE_LOCAL_ROOT=./uploads

# Sprint 2 Feature 5: storage abstraction + at-rest encryption
STORAGE_PROVIDER=local                    # use `supabase` once you've created buckets
STORAGE_BUCKET_PUBLIC=public
STORAGE_BUCKET_PRIVATE=kyc-docs
KYC_DOC_NUMBER_KEY=local-dev-aes-key-rotate-in-prod
```

Restart the backend:

```bash
pnpm dev
```

You should see `Backend listening on http://localhost:3000/api/v1` with no
errors.

> **Skipping Supabase Storage?** Leave `STORAGE_PROVIDER=local`. KYC docs will
> be written to `backend/uploads/kyc-docs/...` and served at `/static/...`.
> The signed-URL contract still holds (it just returns a stable URL locally).

---

## 3. Get a rider session

You should already have an access token from Sprint 1's OTP flow. Verify:

```bash
export ACCESS_TOKEN=<paste-from-/auth/otp/verify>
curl -sS http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq
```

You should see your phone + `roles: ["RIDER"]`. If the token has expired,
re-do `/auth/otp/send` → `/auth/otp/verify` from the Sprint 1 guide.

---

## 4. Feature 1 — User profile

### 4.1 Read your (empty) profile

```bash
curl -sS http://localhost:3000/api/v1/users/me/profile \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq
```

Expect `firstName: null`, `dob: null`, `gender: null`, `avatarUrl: null`.

### 4.2 Update profile

```bash
curl -sS -X PATCH http://localhost:3000/api/v1/users/me/profile \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Mohi",
    "lastName": "Uddin",
    "email": "mohi@example.com",
    "dob": "1995-08-15",
    "gender": "MALE"
  }' | jq
```

Repeat the GET — the response should reflect the new values. Also try
sending `"email": "bad-email"` and confirm a `400 VALIDATION_ERROR` with
`field: "email"`.

### 4.3 Upload an avatar

Grab any JPEG/PNG/WebP under 5 MB. Then:

```bash
curl -sS -X POST http://localhost:3000/api/v1/users/me/avatar \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "avatar=@/path/to/photo.jpg" | jq
```

The response gives you an `avatarUrl`. Open it in a browser — the avatar should
load.

> The file ends up at `backend/uploads/public/avatars/<your-publicId>.jpg`
> and the URL points to `…/static/public/avatars/…`. Re-uploading replaces it.

---

## 5. Feature 2 — Driver profile + KYC

### 5.1 Create driver profile (adds the DRIVER role)

```bash
curl -sS -X POST http://localhost:3000/api/v1/drivers/me/profile \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "emergencyContactName": "Rina Uddin",
    "emergencyContactPhone": "+919812345678"
  }' | jq
```

You should see `kycStatus: "PENDING"`. Re-run the call — it returns the same
profile (idempotent). Then:

```bash
curl -sS http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.data.roles'
```

`roles` now includes `"DRIVER"`. (Your existing access token already worked
because the role check uses the latest DB row, not the token claims.)

### 5.2 Upload KYC docs

`docType` goes in the query string; the file is multipart `file`.

```bash
# Aadhaar
curl -sS -X POST \
  "http://localhost:3000/api/v1/drivers/me/kyc/documents?docType=AADHAAR&docNumber=1234%205678%209012" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@/path/to/aadhaar-front.jpg" | jq

# Driving licence
curl -sS -X POST \
  "http://localhost:3000/api/v1/drivers/me/kyc/documents?docType=DL&expiresAt=2030-12-31" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@/path/to/dl.jpg" | jq
```

Sanity checks:

```bash
# Status auto-flipped to IN_REVIEW once the first doc landed
curl -sS http://localhost:3000/api/v1/drivers/me/kyc/status \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq

# Listing returns fresh signed URLs every call
curl -sS http://localhost:3000/api/v1/drivers/me/kyc/documents \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq
```

The `kyc/status` response should show `status: "IN_REVIEW"`, `uploaded: ["AADHAAR","DL"]`,
`required: ["AADHAAR","DL"]`, `missing: []`. Each list call returns a new
`fileUrl` — open one in the browser to confirm the file is reachable.

> **Encryption sanity check (Feature 5):** open `kyc_documents` in
> Prisma Studio. The `doc_number` column should look like
> `enc:v1:<base64>` — not the raw "1234 5678 9012" you sent. The decrypted
> value appears in `/drivers/me/kyc/documents` and the admin detail.

### 5.3 Delete a doc (optional)

```bash
# Pick a doc id from the list response above
curl -sS -X DELETE \
  "http://localhost:3000/api/v1/drivers/me/kyc/documents/<docId>" \
  -H "Authorization: Bearer $ACCESS_TOKEN" -w "%{http_code}\n"
```

Expect `204`. The status will revert to `PENDING` only if it was the last doc.

---

## 6. Feature 3 — Vehicle management

### 6.1 Register a vehicle

```bash
curl -sS -X POST http://localhost:3000/api/v1/drivers/me/vehicles \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "vehicleType": "CAR",
    "registrationNumber": "WB12AB1234",
    "seatCount": 4,
    "make": "Maruti Suzuki",
    "model": "Swift Dzire",
    "year": 2022,
    "color": "White"
  }' | jq
```

Capture `data.publicId` (e.g. `veh_...`) — you'll need the numeric backend id
in step 8.4, but for now you can look the vehicle up via `GET /drivers/me/vehicles`.

```bash
curl -sS http://localhost:3000/api/v1/drivers/me/vehicles \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq
```

Status should be `PENDING_APPROVAL`.

### 6.2 Upload the vehicle photo

```bash
# vehicleId for the upload route is the numeric internal id — see §8.4 if you
# need it before opening the admin panel. For the driver-side photo upload,
# fetch the vehicle list response and use the numeric id Prisma assigns.
# Easiest: open admin /drivers → click your driver → vehicle card shows the id.
```

For the driver-side photo upload endpoint we use the same numeric `id`. If
you're testing without the admin UI handy, grab it from Prisma Studio's
`vehicles` table.

```bash
curl -sS -X POST \
  "http://localhost:3000/api/v1/drivers/me/vehicles/<id>/photo" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "photo=@/path/to/car.jpg" | jq
```

The response gives `photoUrl`. Open it in a browser — public bucket, no signing
needed.

### 6.3 Edit / delete

```bash
# PATCH — vehicleType + registrationNumber are locked, but cosmetic fields work
curl -sS -X PATCH "http://localhost:3000/api/v1/drivers/me/vehicles/<id>" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color": "Black"}' | jq

# Try to change registrationNumber → 400 (field not whitelisted)
curl -sS -X PATCH "http://localhost:3000/api/v1/drivers/me/vehicles/<id>" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"registrationNumber": "WB99XX9999"}'
```

Don't soft-delete the vehicle yet — you need it for Step 8.

---

## 7. Feature 7 — Register an FCM device token

You need an FCM token from a real mobile / web app to actually receive the
push. For the API contract you can register a dummy token now so the table is
populated; FCM will mark it invalid on the first send and the system will
prune it automatically (that's part of what gets logged in step 8.3).

```bash
curl -sS -X POST http://localhost:3000/api/v1/notifications/device-tokens \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fcmToken": "test-fcm-token-aaaaaaaaaaaaaaaaaaaa",
    "platform": "ANDROID",
    "deviceInfo": { "model": "Test Device" }
  }' -w "%{http_code}\n"
```

Expect `204`. Repeating the call refreshes `lastSeenAt` (check via Prisma
Studio on the `device_tokens` table). Sign-out hook:

```bash
curl -sS -X POST http://localhost:3000/api/v1/notifications/device-tokens/unregister \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fcmToken": "test-fcm-token-aaaaaaaaaaaaaaaaaaaa"}' -w "%{http_code}\n"
```

For the rest of the guide leave at least one token registered so step 8.3 has
something to send to.

---

## 8. Feature 4 + 6 — Admin approval workflow

### 8.1 Boot the admin panel

```bash
cd admin
pnpm dev
# → http://localhost:3001
```

Sign in with your Sprint 1 admin credentials.

### 8.2 `/drivers` list

Click **Drivers** in the sidebar. Your driver row should appear. Verify:

- Phone, account-status badge (`ACTIVE`), KYC badge (`IN REVIEW`), vehicle
  count (`1`).
- Filter dropdowns: pick `KYC: IN_REVIEW` — your driver still shows. Pick
  `KYC: APPROVED` — empty list.
- Search by partial phone — your driver shows.
- Pagination prev/next are disabled when there's only one page.

### 8.3 `/drivers/[id]` detail page

Click the driver's phone to open the detail page.

Verify:

- Profile card shows name, phone, emergency contact, KYC badge.
- "KYC documents (2)" section shows your AADHAAR + DL with thumbnails (or PDF
  icon for PDFs).
- Doc number ("1234 5678 9012") shows under the AADHAAR card — that's the
  decrypted value (the row in the DB is `enc:v1:…`).
- Clicking a doc thumbnail opens the signed URL in a new tab.
- "Vehicles (1)" shows your car with the photo + status badge.

Now hit **Approve KYC**:

- The page reloads with KYC badge → `APPROVED` and "KYC approved at" populated.
- In the backend terminal you should see two log lines:
  ```text
  audit: kyc.approved {"adminUserId":"…","driverUserId":"…","userPublicId":"usr_…"}
  push sent user=… success=0 failed=1 invalid=1
  ```
  `failed=1` is the dummy FCM token failing — that's the expected path. The
  next line proves the system pruned it.
- Recheck `device_tokens` in Prisma Studio — the dummy row is gone.

Try **Approve KYC** while KYC is still `PENDING` (re-test by uploading then
deleting all docs first): the button is greyed out, and a direct API call
returns `409 INVALID_STATE`.

### 8.4 Approve the vehicle

Same page, scroll to the Vehicles section. Click **Approve** on the vehicle
card.

- The vehicle's status flips to `ACTIVE`, `approvedAt` populates.
- Backend logs `audit: vehicle.approved {...}`.

### 8.5 `/vehicles` queue

Click **Vehicles** in the sidebar.

- Default filter is `PENDING_APPROVAL` — empty now that your vehicle is
  `ACTIVE`.
- Switch filter to `ACTIVE` — your vehicle shows with the owner link.
- Click the owner name → bounces back to `/drivers/[id]`.

---

## 9. Rejection paths

Re-upload a fake-bad doc and exercise the rejection flow.

### 9.1 Reject KYC

Driver side:

```bash
# Pretend they re-uploaded a blurry one
curl -sS -X POST \
  "http://localhost:3000/api/v1/drivers/me/kyc/documents?docType=AADHAAR" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@/path/to/aadhaar-front.jpg"
```

Admin side: click the driver → **Reject KYC** → enter a reason like
"Aadhaar photo blurry — please re-upload" → confirm.

- The badge flips to `REJECTED`, "KYC rejection reason" appears.
- Backend logs `audit: kyc.rejected {... "reason":"…"}` and another
  `push sent` line.
- Then have the driver re-upload — the doc upload should auto-flip
  `REJECTED → IN_REVIEW`.

### 9.2 Reject the vehicle

Re-register a vehicle (or use a second one):

```bash
curl -sS -X POST http://localhost:3000/api/v1/drivers/me/vehicles \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "vehicleType": "BIKE",
    "registrationNumber": "WB12CD5678",
    "seatCount": 2
  }' | jq
```

Admin side: `/vehicles` queue → **Reject** → "Photo unreadable" → confirm.

- Status → `INACTIVE`, `rejectedReason` populated.
- Backend logs `audit: vehicle.rejected {...}`.

---

## 10. Optional — switch to Supabase Storage

If you have a Supabase project (Sprint 1 already set one up for the DB):

1. **Storage → New bucket** → name `public`, set **Public** = on.
2. **Storage → New bucket** → name `kyc-docs`, set **Public** = off.
3. Add to `backend/.env.local`:
   ```bash
   STORAGE_PROVIDER=supabase
   SUPABASE_URL=https://<project>.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=<from-Sprint-1>
   ```
4. Restart the backend.

Repeat §4.3 (avatar) and §5.2 (KYC doc) — the files should now appear in the
Supabase Storage dashboard. The avatar URL is a permanent public URL; the KYC
`fileUrl` is a signed URL with `?token=…` and expires after 1 hour. Re-fetch
the admin detail page after an hour to confirm the URL rotates.

---

## 11. Definition of Done — quick checklist

After running this guide you've exercised:

- [ ] **F1** GET/PATCH `/users/me/profile`, POST `/users/me/avatar`
- [ ] **F2** POST/GET/PATCH `/drivers/me/profile`, POST/GET/DELETE `/drivers/me/kyc/documents`, GET `/drivers/me/kyc/status`
- [ ] **F3** POST/GET `/drivers/me/vehicles`, PATCH `/drivers/me/vehicles/:id`, POST `/drivers/me/vehicles/:id/photo`, DELETE soft path
- [ ] **F4** Admin endpoints: GET `/admin/drivers` (paginated + filters), GET `/admin/drivers/:userPublicId`, POST KYC approve/reject, POST vehicle approve/reject
- [ ] **F5** Local + Supabase swap, 1h signed URLs on KYC reads, AES-GCM encrypted `doc_number` at rest
- [ ] **F6** `/drivers`, `/drivers/[id]`, `/vehicles` admin pages working end-to-end
- [ ] **F7** POST `/notifications/device-tokens`, FCM call fires on approve/reject, invalid tokens pruned automatically

If everything passes, Sprint 2 is good to tag (`v0.2.0-sprint-2`).

---

## Common gotchas

| Symptom                                                              | Fix                                                                                                                                                                                |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Environment variable not found: DIRECT_URL` on `prisma migrate …`   | You ran the raw `prisma` CLI. Use the workspace scripts (`pnpm prisma:migrate:deploy`, `pnpm prisma:studio`, etc.) — they wrap Prisma with `dotenv-cli` so `.env.local` is loaded. |
| Backend won't boot: `KYC_DOC_NUMBER_KEY must be base64 of 32 bytes…` | Either omit the line (Zod default kicks in) or set it to `local-dev-aes-key-rotate-in-prod` (exactly 32 ASCII chars).                                                              |
| Avatar URL returns 404                                               | The admin panel uses `:3001`; the avatar URL is on `:3000`. Open in a new tab.                                                                                                     |
| `Driver profile required — POST /drivers/me/profile first`           | You called a `/drivers/me/...` endpoint before creating the driver profile in §5.1.                                                                                                |
| `Driver has not submitted KYC documents yet` on approve              | Driver is still `PENDING` — admin can only approve once they're in `IN_REVIEW` (at least one doc uploaded).                                                                        |
| `push sent ... success=0 failed=1`                                   | Expected if you registered a dummy FCM token in §7. Real device + valid token → `success=1 failed=0`.                                                                              |
| `/sw.js 404` spam in the admin terminal                              | Browser has a stale service worker registered against `:3001`. DevTools → Application → Service Workers → Unregister.                                                              |

---

## What's not in scope here

- Trip booking, matching, payments — Sprint 3+.
- Flutter integration — Postman / curl is what we have for now. Postman
  collection `docs/postman/sprint-02.json` is not yet committed.
- Production Sentry alerts on push failures — Sprint 10.
