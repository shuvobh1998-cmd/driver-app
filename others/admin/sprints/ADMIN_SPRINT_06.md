# Admin Sprint A06 — Payments, Payouts, Wallets

> **Duration:** 2 weeks (parallel with Backend Sprint 8)
> **Goal:** Founder approves a driver's payout request from the UI → driver wallet debits → admin sees the entry on driver's wallet ledger.

## Scope

### Pages

- `/payments` — list w/ filters (status, method, date range)
- `/payments/[id]` — detail + refund button
- `/payouts` — pending queue (default tab) + history tab
- `/payouts/[id]` — detail
- `/drivers/[id]/wallet` — sub-page on driver detail: balance, ledger, manual adjustment

### Components

- `<MoneyDisplay>` — formats integer paise → "₹125.50"
- `<RefundModal>` — full / partial w/ reason
- `<PayoutActionBar>` — approve / mark-paid (with UTR input) / reject
- `<LedgerTable>` — running balance column

### Tasks

- Filter UI + URL state
- Refund flow with confirmation
- Payout action sequence: PENDING → PROCESSING → PAID/REJECTED
- Manual wallet adjustment with required reason

## Endpoints consumed

- `GET /api/v1/admin/payments?...`
- `GET /api/v1/admin/payments/:id`
- `POST /api/v1/admin/payments/:id/refund`
- `GET /api/v1/admin/payouts?status=...`
- `GET /api/v1/admin/payouts/:id`
- `POST /api/v1/admin/payouts/:id/approve`
- `POST /api/v1/admin/payouts/:id/reject`
- `POST /api/v1/admin/payouts/:id/mark-paid`
- `GET /api/v1/admin/drivers/:id/wallet/ledger`
- `POST /api/v1/admin/drivers/:id/wallet/adjust`

## Acceptance

- [ ] Refund flow tested end-to-end (test Razorpay)
- [ ] Payout approval → driver balance debits + ledger entry shows up
- [ ] Manual adjustment requires reason + admin user is logged in audit
- [ ] All amounts displayed correctly (paise → rupees with 2 decimal places)

## Git plan

- `feature/admin-a06-payments-list`
- `feature/admin-a06-refund`
- `feature/admin-a06-payouts-queue`
- `feature/admin-a06-payout-actions`
- `feature/admin-a06-driver-wallet`

## Status

- [ ] Not started

## Delivered

## Notes / Blockers
