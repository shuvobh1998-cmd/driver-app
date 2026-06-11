# Mobile Sprint M06 — Payments + Driver Wallet

> **Duration:** 2 weeks
> **Goal:** Rider completes a UPI test payment after a trip. Driver sees earning credited to wallet. Driver requests payout via UPI. Rider downloads invoice PDF.

## Scope

### Rider screens

- Post-trip payment screen (if UPI): Razorpay sheet (`razorpay_flutter`), success / failure handling
- Saved payment methods list (UPI IDs, masked cards)
- Add new payment method
- Set default
- Trip invoice viewer (in-app) + Download PDF
- Payment history (per trip)

### Driver screens

- Wallet: balance card + "Withdraw" button
- Ledger: paginated entries (CREDIT/DEBIT, reason, amount, balance after)
- Payout request form (amount, UPI ID, optional notes)
- Payout history (PENDING / PROCESSING / PAID / REJECTED states)
- Earnings dashboard: today, this week, this month chips

### Cash flow

- Driver: "Cash collected" button on trip end (when method=CASH)
- Rider: no action needed for cash

## Endpoints integrated

### Rider

- `POST /api/v1/trips/:id/payment/order`
- `POST /api/v1/trips/:id/payment/verify`
- `GET /api/v1/users/me/payment-methods`
- `POST /api/v1/users/me/payment-methods`
- `DELETE /api/v1/users/me/payment-methods/:id`
- `POST /api/v1/users/me/payment-methods/:id/set-default`
- `GET /api/v1/trips/:id/invoice`
- `GET /api/v1/trips/:id/invoice.pdf`

### Driver

- `POST /api/v1/trips/:id/payment/cash-collected`
- `GET /api/v1/drivers/me/wallet`
- `GET /api/v1/drivers/me/wallet/ledger`
- `POST /api/v1/drivers/me/payouts/request`
- `GET /api/v1/drivers/me/payouts`
- `GET /api/v1/drivers/me/payouts/:id`
- `GET /api/v1/drivers/me/earnings/today`
- `GET /api/v1/drivers/me/earnings/this-week`
- `PUT /api/v1/drivers/me/payout-method`

### Critical

- `Idempotency-Key` header on all payment-verify and payout-request POSTs

## Acceptance

- [ ] UPI test payment completes; driver wallet auto-credits (minus platform fee + GST)
- [ ] Cash trip: driver taps "Cash collected" → trip closes; driver wallet debits platform fee
- [ ] Driver requests ₹500 payout → admin sees in queue → admin marks paid → driver balance reflects
- [ ] Invoice PDF downloads and opens in default viewer
- [ ] Saved UPI ID persists across sessions
- [ ] All amounts display correctly (paise → "₹125.50")

## Status

- [x] Backend API delivered + verified end-to-end (Flutter app build is the mobile team's task)

## Delivered

> Our deliverable = the backend endpoints + Swagger + WS events the Flutter team consumes.
> New `payments` module (migration `0018_payments_wallet_payouts`).

**Rider — payments**

- `POST /trips/:id/payment/order` — create a Razorpay order for a finished
  UPI/CARD trip (returns `gatewayOrderId` + `razorpayKeyId` for the SDK sheet).
- `POST /trips/:id/payment/verify` — verify the client-returned signature,
  settle the trip, credit the driver wallet. **`Idempotency-Key` required.**
- `GET/POST/DELETE /users/me/payment-methods` + `POST …/:id/set-default` —
  saved UPI/card methods (first one auto-default; delete promotes the next).
- `GET /trips/:id/invoice` (JSON) + `GET /trips/:id/invoice.pdf` (binary PDF,
  `Content-Disposition: attachment`). Accessible to rider, driver or admin.

**Driver — wallet, earnings, payouts, cash**

- `POST /trips/:id/payment/cash-collected` — close a CASH trip; debits the
  platform commission + GST from the wallet. **`Idempotency-Key` required.**
- `GET /drivers/me/wallet` + `GET /drivers/me/wallet/ledger` (paginated).
- `GET /drivers/me/earnings/{today,this-week,this-month}` (IST windows).
- `PUT/GET /drivers/me/payout-method` (UPI or bank; account number masked on read).
- `POST /drivers/me/payouts/request` (**`Idempotency-Key` required**; debits the
  wallet immediately so it can't be double-withdrawn) · `GET /drivers/me/payouts`
  · `GET /drivers/me/payouts/:id`.

**Admin — payout processing** (for the acceptance "admin marks paid" loop)

- `GET /admin/payouts?status=` (queue) · `PATCH /admin/payouts/:id`
  (PENDING → PROCESSING → PAID, or → REJECTED which reverses the wallet debit).

**Money model.** Commission split is a PLACEHOLDER pending founder decision
(open question #2): `PLATFORM_COMMISSION_BPS` (10%) + `PLATFORM_GST_BPS` (5%) on
the gross fare. UPI/CARD: platform collects the fare, driver wallet is credited
the net earning. CASH: driver keeps the fare, wallet is debited commission+GST
(balance may go negative — the debt the driver owes, recovered from future
earnings/payouts). All amounts integer paise.

**Razorpay.** Behind a provider abstraction. `PAYMENT_PROVIDER=mock` (default,
dev) signs orders with the **exact HMAC Razorpay uses** (`HMAC_SHA256(order_id|
payment_id, key_secret)`), so the verify contract is real before live keys
exist; flip to `razorpay` once test keys are provisioned (lazy-loads the
`razorpay` package).

**Idempotency** (`docs/API_CONVENTIONS.md`). `@Idempotent()` interceptor stores
`(userId, key) → response` for `IDEMPOTENCY_TTL_HOURS` (24h); a replay returns
the stored response, a replay with a different body is `409
IDEMPOTENCY_KEY_REUSED_DIFFERENT_BODY`, a missing key is `400`.

**End-to-end verification** (real Supabase): order → verify (correct HMAC) →
**PAID**, split `12550 = 1255 commission + 628 GST + 10667 driver` → wallet
credited → idempotent replay returns the same payment → different body **409** →
missing key **400**. Cash-collected → commission **debit 1883**, balance
`30118` → idempotent replay → re-collect **409 DUPLICATE**. Saved methods:
first=default, set-default flips, delete promotes. Payout: request below min
**422**, over balance **422**, valid request debits → admin PROCESSING → PAID
(stamps `totalPaidOut`) → second request → admin REJECT reverses the debit
(balance restored). Earnings: 4 trips, gross `50200`, net `42668`. Invoice JSON

- valid 1-page PDF (2.1 KB, `application/pdf`). 304 unit tests green.

## Notes

- **Acceptance "amounts display correctly (paise → ₹125.50")"** — the backend
  returns integer paise on every field; `invoice.totalFormatted` is the one
  pre-formatted string (`₹125.50`). Formatting elsewhere is the app's job.
- **Commission % is a placeholder** (open question #2). It's env-driven
  (`PLATFORM_COMMISSION_BPS` / `PLATFORM_GST_BPS`) so the founder's final numbers
  are a config change, not a code change. The split is snapshotted onto each
  `payments` row + ledger entry, so changing it later doesn't rewrite history.
- **PDF is dependency-free** — a tiny hand-rolled single-page writer (no pdfkit).
  WinAnsi has no rupee glyph, so the PDF prints `Rs.` while the JSON uses `₹`.
- **Razorpay webhook** (`POST /webhooks/razorpay`) is **not** built — settlement
  is driven by the client `verify` call for MVP. A webhook backstop (for
  payments confirmed after the app closes) is a hardening task for a later sprint.
- **`cash-collected` takes no body** — send the POST without a `Content-Type:
application/json` header (an empty JSON body is rejected by the global
  validator). Flutter should POST with no body.
