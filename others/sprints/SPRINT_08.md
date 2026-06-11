# Sprint 8 — Payments & Wallet

> **Duration:** 2 weeks
> **Theme:** Razorpay integration, cash + UPI flows, driver wallet, earnings, payouts, invoices

## Goal

Founder sees a driver's wallet balance auto-increment immediately after a UPI-paid trip ends. Founder issues a payout from admin → driver's balance debits.

## Why this sprint

Until money moves, this is just a demo. After this sprint, the on-demand product is monetizable. Even though we run on Razorpay test keys, the _flows_ must be production-shape.

## Features

### 1. Razorpay integration (test mode)

- Create Razorpay account, get test keys
- Order creation flow: when trip ends with `method=UPI/CARD`, create Razorpay order → return `orderId + key` to rider
- Rider pays in app → app sends `paymentId + signature` → backend verifies signature
- Webhook listener: `/api/v1/webhooks/razorpay` — verify HMAC, mark payment success/failure
- Idempotency via `Razorpay-Event-Id` header

### 2. Payment flows

- **Cash:** driver collects, marks `POST /trips/:id/payment/cash-collected` → payment row SUCCESS
- **UPI/Card:** Razorpay flow above
- **Wallet:** debit from rider wallet (Phase 2 — not in MVP)

### 3. Driver wallet & earnings

- On every successful trip payment, driver wallet auto-credited (after platform fee + GST deduction)
- Append entry to `wallet_ledger` (CREDIT, reason=TRIP_EARNING)
- Cash trips: driver wallet _debited_ by platform fee (driver "owes" the company the cut)
- `GET /api/v1/drivers/me/wallet` — current balance
- `GET /api/v1/drivers/me/wallet/ledger` — paginated history

### 4. Payouts (manual approval in MVP)

- `POST /api/v1/drivers/me/payouts/request` — body `{ amount, method, upiId or bankDetails }`
- `GET /api/v1/admin/payouts` — pending queue
- `POST /api/v1/admin/payouts/:id/approve` — marks PROCESSING (manual bank transfer happens off-system in MVP)
- `POST /api/v1/admin/payouts/:id/mark-paid` — body `{ utr/referenceNumber }`
- `POST /api/v1/admin/payouts/:id/reject` — body `{ reason }`
- Wallet debited on payout approval, ledger entry added

### 5. Invoices

- `GET /api/v1/trips/:id/invoice` — JSON invoice (rider)
- `GET /api/v1/trips/:id/invoice.pdf` — PDF invoice (rider/driver)
- Generated server-side via Puppeteer or `pdfkit`
- Includes GSTIN placeholder (filled when business has one)

### 6. Refunds

- `POST /api/v1/admin/payments/:id/refund` — body `{ amount, reason }`
- Full refund triggers Razorpay refund + wallet adjustment if needed
- Partial refund supported

### 7. Admin pages

- `/payments` — list, filter by status/method/date
- `/payments/[id]` — detail + refund action
- `/payouts` — pending queue + history
- `/drivers/[id]/wallet` — driver's balance + ledger

### 8. Cancellation fees (policy)

- Configurable per vehicle type
- Charged when rider cancels after driver is en route (>2 min after accept)
- Driver gets cancellation fee credited

## API endpoints delivered

| Method | Path                                       | Auth        | Purpose               |
| ------ | ------------------------------------------ | ----------- | --------------------- |
| POST   | `/api/v1/trips/:id/payment/cash-collected` | driver      | Mark cash paid        |
| POST   | `/api/v1/trips/:id/payment/order`          | rider       | Create Razorpay order |
| POST   | `/api/v1/trips/:id/payment/verify`         | rider       | Verify signature      |
| POST   | `/api/v1/webhooks/razorpay`                | none (HMAC) | Razorpay webhook      |
| GET    | `/api/v1/drivers/me/wallet`                | driver      | Balance               |
| GET    | `/api/v1/drivers/me/wallet/ledger`         | driver      | Ledger                |
| POST   | `/api/v1/drivers/me/payouts/request`       | driver      | Request payout        |
| GET    | `/api/v1/admin/payouts`                    | admin       | Queue                 |
| POST   | `/api/v1/admin/payouts/:id/approve`        | admin       | Approve               |
| POST   | `/api/v1/admin/payouts/:id/mark-paid`      | admin       | Mark paid             |
| POST   | `/api/v1/admin/payouts/:id/reject`         | admin       | Reject                |
| GET    | `/api/v1/trips/:id/invoice`                | rider       | JSON invoice          |
| GET    | `/api/v1/trips/:id/invoice.pdf`            | rider       | PDF                   |
| POST   | `/api/v1/admin/payments/:id/refund`        | admin       | Refund                |

## DB migrations this sprint

1. `0020_payments` — `payments` table
2. `0021_wallet_accounts_ledger` — `wallet_accounts`, `wallet_ledger`
3. `0022_payouts` — `payouts` table
4. `0023_cancellation_fees` — config table or addition to `pricing_rules`

## Admin panel pages this sprint

| Page                   | Purpose                 |
| ---------------------- | ----------------------- |
| `/payments`            | All payments            |
| `/payments/[id]`       | Payment detail + refund |
| `/payouts`             | Pending payouts queue   |
| `/drivers/[id]/wallet` | Driver wallet + ledger  |

## API for Mobile (what Flutter devs consume)

> Our mobile deliverable = these endpoints + Razorpay test keys + Swagger + Postman. No Flutter code from us; Flutter devs wire up `razorpay_flutter` SDK against our endpoints.

**Rider endpoints shipped:**

- `POST /api/v1/trips/:id/payment/order` — creates Razorpay order → returns `{ orderId, key, amount, currency }`
- `POST /api/v1/trips/:id/payment/verify` — body `{ razorpayPaymentId, razorpaySignature }` → server verifies HMAC, returns `{ status }`
- `GET /api/v1/trips/:id/invoice` — JSON invoice
- `GET /api/v1/trips/:id/invoice.pdf` — PDF download

**Driver endpoints shipped:**

- `POST /api/v1/trips/:id/payment/cash-collected` — confirm cash receipt
- `GET /api/v1/drivers/me/wallet` — balance (paise)
- `GET /api/v1/drivers/me/wallet/ledger` — paginated history
- `POST /api/v1/drivers/me/payouts/request` — body `{ amount, method, upiId?, bankDetails? }`

**WebSocket events:** none new (payment status is fetched via verify endpoint; future enhancement could push `payment.success`).

**Razorpay flow Flutter must implement:**

1. Trip ends → app calls `POST /trips/:id/payment/order` → gets `{ orderId, key }`
2. App opens Razorpay SDK with that order → user pays
3. SDK returns `{ paymentId, signature }` → app calls `POST /trips/:id/payment/verify`
4. On verify success → show receipt; wallet auto-credits driver in background

**Conventions Flutter must match:**

- All amounts in integer paise (e.g., `12500` for ₹125)
- Razorpay key is test mode for now (`rzp_test_…`); we'll swap in Sprint 10 for live
- Cash flow: driver-side single button "Mark cash collected" after trip ends

**Artifacts:**

- Postman collection: `docs/postman/sprint-08.json`
- Razorpay test card numbers in [`docs/FREE_TIER_GUIDE.md`](../FREE_TIER_GUIDE.md)

**Unblocks mobile sprint M06** — UPI checkout, cash collection button, wallet view, payout request screen, invoice download. See [`docs/mobile/sprints/MOBILE_SPRINT_06.md`](../mobile/sprints/MOBILE_SPRINT_06.md).

## Demo checklist

- [ ] Complete a UPI test payment via Razorpay test mode
- [ ] Driver wallet auto-credited (minus platform fee + GST)
- [ ] Ledger entry visible in admin
- [ ] Driver requests ₹500 payout via Postman
- [ ] Founder approves payout, marks paid with UTR
- [ ] Driver balance reflects debit
- [ ] Generate trip invoice PDF, open in browser
- [ ] Issue a test refund

## Definition of Done

- [ ] Webhook signature verification works (tested with Razorpay test webhook)
- [ ] All money math in integer paise (no floats)
- [ ] Idempotency: replaying webhook does not double-credit
- [ ] Wallet balance always equals sum of ledger entries (invariant test)
- [ ] PDF invoice renders correctly
- [ ] Refund flow tested
- [ ] Cancellation fee tested in both directions (rider-late vs driver-late)
- [ ] Git tag `v0.8.0-sprint-8`

## Git plan

- `feature/sprint-8-razorpay-setup`
- `feature/sprint-8-payment-flows` — order/verify/cash/webhook
- `feature/sprint-8-wallet-ledger`
- `feature/sprint-8-payouts`
- `feature/sprint-8-invoices`
- `feature/sprint-8-refunds`
- `feature/sprint-8-admin-payments`

## Status

- [ ] Not started

## Delivered

## Carryover

## Notes / Blockers
