# Firebase Auth — Phone OTP Setup (full walkthrough)

This doc gets you from **no Firebase account** to **working OTP login**
end-to-end. No prior Firebase knowledge assumed.

---

## 0. Concepts (read this once — saves confusion later)

### 0.1 Firebase project vs Firebase apps

A **Firebase project** is one container that holds all of your Auth users,
your Firestore/Storage data, your Cloud Messaging configuration, etc.

Inside that one project, you register one or more **"apps"** — one per
client platform that talks to Firebase. The options Firebase offers are:

| Firebase app type | Used by                              | Needed for this project?          |
| ----------------- | ------------------------------------ | --------------------------------- |
| **Web** (`</>`)   | Browsers + Node.js + the tester page | ✅ Yes — for the OTP tester in §6 |
| **Android**       | The Flutter app's Android build      | Later — Flutter devs add this     |
| **iOS**           | The Flutter app's iOS build          | Later — Flutter devs add this     |
| **Unity / C++**   | Game engines                         | ❌ No                             |

> **Flutter is not its own Firebase app type.** Flutter generates real
> Android + iOS builds. So when the Flutter team is ready, they'll register
> **one Android app + one iOS app** under the same project and use the
> `flutterfire configure` CLI to wire them up. You don't do that now — it's
> their job in a later sprint.

### 0.2 What does the backend register as?

**Nothing.** The backend (NestJS) does not register as a Firebase app.

Servers use a different credential called a **service account** — a JSON
file with a private key that lets the Firebase Admin SDK act on behalf of
the entire project. Pasted into `backend/.env.local` as three env vars.

### 0.3 So what do you create today?

| Thing                  | Why                                                                  | Section |
| ---------------------- | -------------------------------------------------------------------- | ------- |
| 1 Firebase project     | The container                                                        | §2      |
| Phone provider enabled | Lets users sign in with phone+OTP                                    | §3      |
| 1 Web app              | So the browser tester (`tools/firebase-otp-tester/index.html`) works | §4      |
| 1 service account      | So the backend can verify ID tokens                                  | §5      |

That's it. Android + iOS apps come later when Flutter devs start.

### 0.4 How the OTP flow works (5-second summary)

```
[Flutter / browser tester]                       [Firebase]              [Your backend]
1. user enters phone   ────────────────────────►  signInWithPhoneNumber
                                                  Firebase sends SMS
2. user enters code    ────────────────────────►  Firebase verifies code
                                                  Firebase returns ID token
3. Client sends ID token  ─────────────────────────────────────────────►  POST /auth/otp/verify
                                                                          backend calls
                                                                          firebase.verifyIdToken()
                                                                          ┌────────────────┐
                                                                          │ creates user,  │
                                                                          │ returns JWTs   │
                                                                          └────────────────┘
```

The backend **never sends an SMS itself.** Firebase does. The backend only
verifies the cryptographic ID token that Firebase issued to the client.
That's why `POST /auth/otp/send` is rate-limit-only on our side — the real
SMS dispatch happens in the client SDK.

---

## 1. Prerequisites

- A Google account (any Gmail address). Firebase is a Google product.
- The backend running locally (`pnpm --filter backend dev`).
- The repo cloned (so you can edit `backend/.env.local`).

---

## 2. Create the Firebase project

1. Open <https://console.firebase.google.com> in a browser. Sign in with the
   Google account.
2. If it's your first time, accept the Firebase terms.
3. Click the big **"Create a Firebase project"** card (or **"+ Add
   project"** if you already have other projects).
4. **Step 1 — Project name.**
   - Name: `rideshare-dev` (or whatever you want — must be globally unique
     so Firebase may append a `-1234` suffix).
   - Accept the terms checkbox.
   - Click **Continue**.
5. **Step 2 — Google Analytics.**
   - Toggle **OFF** ("Disable Google Analytics for this project").
   - You don't need analytics for a dev project, and turning it on forces
     you to pick or create an Analytics account.
   - Click **Create project**.
6. Wait ~30 seconds. When you see "Your new project is ready", click
   **Continue**.

You land on the project's **Overview** page. The project name is shown in
the top-left.

---

## 3. Enable the Phone sign-in provider

1. In the left sidebar, find **Authentication** (under **Project shortcuts**
   if you've used Firebase before, or under **Build** in the **Product
   categories** section). Click it.
2. You'll see a landing page with a big orange **"Get started"** button and
   a purple panel showing Android / iOS / Web mockups. Click **Get
   started**.

   > ⚠️ Do **not** click **"Phone Verification [NEW]"** in the left
   > sidebar. That's a separate newer Firebase product. We need the classic
   > **Authentication** product.

3. You land on the **Sign-in method** tab with a list of providers (Email,
   Google, Apple, Phone, Anonymous, etc.).
4. Click **Phone** in the list.
5. A side panel opens. Toggle **Enable** to **ON**.
6. Scroll down inside the same panel to **Phone numbers for testing
   (optional)**.
7. Add one whitelisted test pair:
   - **Phone number:** `+91 99999 00000` (any number — but use one you
     don't actually own, so Firebase doesn't try to bill an SMS later if
     you misconfigure something).
   - **Verification code:** `123456`
   - Click **Add**.
8. Click **Save** at the bottom of the panel.

The Phone row should now show **Enabled**.

> **Why test numbers matter:** Whitelisted numbers bypass real SMS
> dispatch. Firebase accepts the fixed code (`123456`) without sending a
> message. Spark (free) plan gets a tiny SMS quota — test numbers let you
> develop without burning it.

---

## 4. Register a Web app (for the browser tester)

1. Click the **gear icon** in the top-left of the sidebar → **Project
   settings**.
2. Scroll to the **Your apps** section. It's empty.
3. Click the **`</>`** (Web) icon. (The other icons are Android / iOS / Unity
   — ignore them today.)
4. **App nickname:** `rideshare-otp-tester` (this is just an internal
   label).
5. Leave **"Also set up Firebase Hosting"** unchecked. Click **Register
   app**.
6. The next screen shows a code snippet labeled **"Add Firebase SDK"**.
   Inside it is a `firebaseConfig` object. **Copy the whole object.** It
   looks like:

   ```js
   const firebaseConfig = {
     apiKey: 'AIzaSyB-xxxxxxxxxxxxxxxxxxxxxxx',
     authDomain: 'rideshare-dev-1234.firebaseapp.com',
     projectId: 'rideshare-dev-1234',
     storageBucket: 'rideshare-dev-1234.appspot.com',
     messagingSenderId: '123456789012',
     appId: '1:123456789012:web:abcdef1234567890',
   };
   ```

   You'll paste these 4 fields (apiKey / authDomain / projectId / appId)
   into the tester page in §7.

7. Click **Continue to console**.
8. Back on the **Project settings** page, scroll to **Authentication →
   Authorized domains** (or go to **Authentication → Settings → Authorized
   domains** in the left sidebar). Confirm `localhost` is in the list. It
   is by default — but verify, because the tester serves from
   `http://localhost:5173`.

---

## 5. Generate a service account (backend credentials)

1. Still in **Project settings**, click the **Service accounts** tab at the
   top.
2. You'll see a panel saying "Firebase Admin SDK". Click **Generate new
   private key**.
3. A confirmation dialog warns "Keep your private key confidential". Click
   **Generate key**.
4. A JSON file downloads to your computer. Name will be something like
   `rideshare-dev-1234-firebase-adminsdk-abcde-1a2b3c4d5e.json`.
5. **Do not commit this file.** Treat it like a password.
6. Open the JSON in a text editor. It has these fields (among others):

   ```json
   {
     "type": "service_account",
     "project_id": "rideshare-dev-1234",
     "private_key_id": "...",
     "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQ...\n-----END PRIVATE KEY-----\n",
     "client_email": "firebase-adminsdk-abcde@rideshare-dev-1234.iam.gserviceaccount.com",
     ...
   }
   ```

7. You need **three** of those fields. Map them to env vars:

   | JSON field     | Env var in `backend/.env.local` |
   | -------------- | ------------------------------- |
   | `project_id`   | `FIREBASE_PROJECT_ID`           |
   | `client_email` | `FIREBASE_CLIENT_EMAIL`         |
   | `private_key`  | `FIREBASE_PRIVATE_KEY`          |

---

## 6. Update `backend/.env.local`

Open `backend/.env.local` and replace the three Firebase stub values:

```bash
FIREBASE_PROJECT_ID=rideshare-dev-1234
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-abcde@rideshare-dev-1234.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQ...truncated...==\n-----END PRIVATE KEY-----\n"
```

### Critical rules for `FIREBASE_PRIVATE_KEY`

1. **Wrap the whole value in double quotes.**
2. **Keep the literal `\n` escape sequences as-is** — do not press Enter or
   replace them with real newlines. `FirebaseAdminService.onModuleInit()`
   converts `\n` back to real newlines before passing the key to the SDK
   (see [`backend/src/firebase/firebase-admin.service.ts`](../backend/src/firebase/firebase-admin.service.ts)
   line 32: `rawKey.replace(/\\n/g, '\n')`).
3. **Copy the value from the JSON exactly** — including the `\n`s, the
   `-----BEGIN PRIVATE KEY-----` header, the `-----END PRIVATE KEY-----`
   footer, and the trailing `\n` at the end.

A working example (real shape, fake content):

```bash
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n-----END PRIVATE KEY-----\n"
```

After saving, **delete the downloaded service-account JSON** from your
Downloads folder. The values are now in `.env.local` (which is in
`.gitignore`).

---

## 7. Restart the backend and run the tester

### 7.1 Restart backend

In the terminal where backend is running:

```bash
# Ctrl+C
pnpm --filter backend dev
```

Watch the boot logs. You want to see:

```
[Nest] LOG [FirebaseAdminService] Firebase Admin SDK initialized
```

with **no** warning that says `Falling back to applicationDefault()`. If
the warning appears, your private key is malformed — most often the
double-quote wrapping got lost. Re-do §6.

### 7.2 Configure the browser tester

1. Open [`tools/firebase-otp-tester/index.html`](../tools/firebase-otp-tester/index.html)
   in your editor.
2. Find the `firebaseConfig` object near the top of the `<script>` block.
3. Replace the four `__REPLACE_ME__` slots with the values you copied in
   §4.6:

   ```js
   const firebaseConfig = {
     apiKey: 'AIzaSyB-xxxxxxxxxxxxxxxxxxxxxxx',
     authDomain: 'rideshare-dev-1234.firebaseapp.com',
     projectId: 'rideshare-dev-1234',
     appId: '1:123456789012:web:abcdef1234567890',
   };
   ```

4. Save the file.

### 7.3 Serve the tester

```bash
cd tools/firebase-otp-tester
python3 -m http.server 5173
```

Open <http://localhost:5173> in a browser.

> ⚠️ You **must** open via `http://localhost:5173` — Firebase Auth refuses
> `file://` origins. Don't double-click the HTML file in your file
> manager.

### 7.4 Run the OTP flow

1. **Phone field:** type `+919999900000` (the test number you whitelisted
   in §3.7 — leading `+` and country code required).
2. Solve the **reCAPTCHA** checkbox that appears (might be invisible for
   test numbers).
3. Click **Send code**. The page should print "Code sent."
4. **SMS code field:** type `123456` (your whitelisted code).
5. Click **Verify & get ID token**.
6. The page prints the Firebase ID token, then auto-POSTs it to
   `http://localhost:3000/api/v1/auth/otp/verify`.
7. Below, you should see the backend response: **HTTP 200** with a JSON
   body containing `accessToken`, `refreshToken`, and a `user` object with
   the phone number.

### 7.5 Smoke-test the access token

Copy the `accessToken` from the response and call the `me` endpoint:

```bash
curl -s http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer <PASTE_ACCESS_TOKEN_HERE>" | jq
```

You should get the same user record back. If yes — **OTP is fully live.**

---

## 8. What about Flutter / Android / iOS?

When the Flutter team is ready to integrate (Sprint 5 per the roadmap),
they will:

1. Stay in the **same Firebase project** (`rideshare-dev`).
2. Open **Project settings → Your apps** → click the **Android** icon →
   register the Android package name (e.g.
   `com.rideshare.app`) → download `google-services.json`.
3. Click the **iOS** icon → register the iOS bundle ID → download
   `GoogleService-Info.plist`.
4. Run `flutterfire configure` in their Flutter project — that CLI reads
   both files and generates `firebase_options.dart`.
5. Their Flutter `signInWithPhoneNumber()` call uses the same Phone
   provider you just enabled, and the ID token it returns will pass through
   the same `POST /auth/otp/verify` endpoint with no backend changes.

So nothing on the backend side changes when mobile comes online. Same
project, same service account, just more registered apps.

---

## 9. Production checklist (for the deploy sprint — not now)

When you're ready to flip to production:

- [ ] Create a **separate** Firebase project (`rideshare-prod`) — never share
      a project between dev and prod.
- [ ] Remove all test phone numbers from the prod project.
- [ ] Add Android SHA-1 / SHA-256 fingerprints under Project settings →
      Your apps → Android → Add fingerprint (Flutter team provides these
      from their release keystore).
- [ ] Upload an APNs auth key under **Cloud Messaging → Apple app
      configuration**.
- [ ] If the admin panel ever calls Firebase Auth directly, add the prod
      Vercel domain under **Authentication → Settings → Authorized
      domains**. (Today admin uses email+password, so this is not needed.)
- [ ] Configure abuse limits under **Authentication → Settings → User
      actions** (per-IP / per-phone).
- [ ] Generate a new service account for prod and store its values in your
      hosting provider's secret manager (Render env vars), not committed.

---

## 10. Troubleshooting

| Symptom                                                                         | Likely cause                                                                       | Fix                                                                                                                               |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Backend boot log: `Falling back to applicationDefault()`                        | `FIREBASE_PRIVATE_KEY` is malformed.                                               | Re-paste with double quotes around the entire value and literal `\n` (backslash + n) for line breaks. See §6 critical rules.      |
| Backend boot log: `Failed to parse private key`                                 | Same as above.                                                                     | Same as above.                                                                                                                    |
| `verifyOtp` returns `UNAUTHENTICATED` / `Firebase ID token has incorrect "aud"` | `FIREBASE_PROJECT_ID` doesn't match the project that minted the token.             | The tester's `firebaseConfig.projectId` (§7.2) and the backend's `FIREBASE_PROJECT_ID` (§6) must be the same string.              |
| Tester: `auth/operation-not-allowed`                                            | Phone provider not enabled in the project.                                         | Re-do §3.                                                                                                                         |
| Tester: `auth/invalid-app-credential` after clicking Send code                  | reCAPTCHA blocked, or `localhost` not in Authorized domains.                       | Hard refresh (Cmd+Shift+R / Ctrl+Shift+R). Verify §4.8.                                                                           |
| Tester: `auth/invalid-phone-number`                                             | Missing `+` or country code.                                                       | Use `+919999900000` format.                                                                                                       |
| Tester: `auth/too-many-requests`                                                | Burned the per-IP free-tier limit.                                                 | Wait an hour, or rotate to a different test phone number.                                                                         |
| Tester: clicks Send but no SMS arrives, and the phone isn't a test number       | Spark plan only sends SMS to whitelisted test numbers + a handful of real numbers. | Add the real number under §3.7, or just use the test pair.                                                                        |
| Backend logs: `prepared statement "s0" already exists`                          | Supabase Transaction pooler without `?pgbouncer=true`.                             | Already fixed — see commit `053a932`. Check `backend/.env.local` `DATABASE_URL` ends with `?pgbouncer=true&connection_limit=1`.   |
| Tester shows "Network error" when POSTing to backend                            | Backend not running, or CORS blocked.                                              | Confirm backend logs show `Backend listening on http://localhost:3000/api/v1`. CORS is set to `origin: true` so any origin works. |
| Tester serves but blank page                                                    | Opened via `file://` instead of `http://`.                                         | Use `python3 -m http.server 5173` and open `http://localhost:5173`.                                                               |
