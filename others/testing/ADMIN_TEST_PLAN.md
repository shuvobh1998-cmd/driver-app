# Admin Test Plan

> Manual smoke checklist before every sprint demo. Optional Playwright for the 5 critical flows.

## Manual smoke checklist (run before each demo)

Time required: ~15 min. Test against the Vercel preview URL.

### Auth

- [ ] Open `/login` in incognito → form renders
- [ ] Wrong password → error shown, no kick
- [ ] Correct credentials → land on dashboard, sidebar visible
- [ ] Refresh page → still logged in (cookie / token persistence)
- [ ] Logout → back to login

### Navigation

- [ ] Every sidebar link routes to a non-404 page
- [ ] Breadcrumbs render on every page
- [ ] 404 page exists for invalid paths

### Users

- [ ] `/users` list loads, paginates
- [ ] Search by phone returns matching user
- [ ] Click row → opens detail page
- [ ] Detail page shows recent trips (if any)

### Drivers (after Sprint A02)

- [ ] `/drivers` list loads, filter chips work
- [ ] Open detail of a pending-KYC driver
- [ ] View each KYC doc (images load via signed URL)
- [ ] Reject with reason → status updates
- [ ] Approve a real driver → push lands on test driver device (or visible in backend logs)

### Pricing (after Sprint A03)

- [ ] Pricing page loads with seeded rules
- [ ] Edit AUTO per-km → save → reflected in next `/fares/estimate` curl
- [ ] History audit shows the change with admin username

### Live map (after Sprint A04)

- [ ] `/live-map` shows pins for any online driver
- [ ] Filter chips work
- [ ] WS reconnects after network drop (test with Chrome DevTools throttling)

### Trips (after Sprint A05)

- [ ] `/trips` list paginates, filters work
- [ ] Detail page renders replay map
- [ ] Live page updates in real time

### Payments (after Sprint A06)

- [ ] `/payments` list filter by status works
- [ ] Refund flow works (test Razorpay)
- [ ] `/payouts` shows pending queue
- [ ] Approving a payout updates driver wallet

### Carpool (after Sprint A07)

- [ ] `/scheduled-trips` list loads
- [ ] Cancel a test trip → bookings refunded

### Support (after Sprint A08)

- [ ] `/support/tickets` queue loads
- [ ] Open ticket, reply → user gets push

### Content CMS (after Sprint A08)

- [ ] Create new FAQ → publish → fetch via `GET /content/faq`

### Errors

- [ ] Trigger a backend 500 (force-stop backend briefly) → admin shows error toast, not white screen
- [ ] Throttle network in DevTools → loading skeletons appear

### Responsive

- [ ] Sidebar collapses on screens < 1024px
- [ ] Tables scroll horizontally on mobile breakpoint (admin works on tablet)

## Optional Playwright tests

Set up `admin/e2e/` with Playwright. 5 critical specs:

```
e2e/
├── auth.spec.ts            # login + logout + 401 redirect
├── drivers-kyc.spec.ts     # approve a seeded driver
├── pricing.spec.ts         # change a rule + verify audit
├── live-map.spec.ts        # WS connects + pin appears
└── trip-detail.spec.ts     # detail page loads + map renders
```

Run on PR (only if it's a quick win — don't block sprint velocity for it).

## Browsers to test against

- Chrome latest (primary)
- Firefox latest
- Safari latest (founder may use Mac)
- Edge latest (some Windows users)

Skip IE 11 — out of scope.

## Performance baselines

- TTI (time-to-interactive) on dashboard < 2s on a 4G connection
- Live-map FPS > 30 with 50 driver pins
- Bundle size < 500KB initial (Next.js handles this with code-splitting)
