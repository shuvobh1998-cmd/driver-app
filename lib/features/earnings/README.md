# earnings

D5 — Earnings, wallet & payouts: dashboard, wallet ledger, cash-collected close,
payout method, withdrawals, and the trip invoice viewer. All money is integer
**paise**, rendered through `shared/utils/money.dart#formatPaise`.

## Flow

1. **Dashboard** ([screens/earnings_dashboard_screen.dart](presentation/screens/earnings_dashboard_screen.dart))
   — net + gross for today / this-week / this-month, trip counts, and a simple
   comparison bar; shortcuts into the wallet and payouts.
2. **Wallet** ([screens/wallet_screen.dart](presentation/screens/wallet_screen.dart))
   — balance + lifetime totals over the paginated ledger (CREDIT/DEBIT, reason,
   `balanceAfter`).
3. **Payouts** — set a UPI/BANK payout method, request a withdrawal (≤ balance),
   and follow each payout's status. Driven by `requestPayout` (idempotent).
4. **Cash-collected** — wired into the trip summary
   ([trips/.../trip_summary_screen.dart](../trips/presentation/screens/trip_summary_screen.dart)):
   on a finished CASH trip the driver settles commission + GST from the wallet.
5. **Invoice** ([screens/invoice_screen.dart](presentation/screens/invoice_screen.dart))
   — JSON line items + total, with an "Open PDF" that downloads the authenticated
   `invoice.pdf` to a temp file and hands it to the OS viewer (`open_filex`).

## Layers

- `data/` — [earnings_api.dart](data/earnings_api.dart) (REST), models + enums,
  and [earnings_providers.dart](data/earnings_providers.dart).
- `presentation/controllers/` — `LedgerController` + `PayoutsController`
  (paginated, mirroring `TripHistoryController`).
- `presentation/screens` + `presentation/widgets`.

## Endpoints

`GET /drivers/me/wallet` · `/wallet/ledger` ·
`/earnings/{today|this-week|this-month}` · `GET/PUT /drivers/me/payout-method` ·
`POST /drivers/me/payouts/request` (⊕ idempotent) · `GET /drivers/me/payouts` ·
`/payouts/:id` · `POST /trips/:id/payment/cash-collected` (⊕ idempotent) ·
`GET /trips/:id/invoice` · `/invoice.pdf`.

> `Idempotency-Key` is attached automatically by the network interceptor on the
> money-moving POSTs, so a retried tap settles exactly once.

See `docs/DRIVER_APP_SPRINT_PLAN.md` (D5).
