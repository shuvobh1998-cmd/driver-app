# Sprint 3 — Manual Testing Guide

End-to-end walkthrough of every Sprint 3 feature with seeded data. Bypasses Firebase OTP via the `pnpm dev:token` helper (dev/test only — never exposed in prod).

---

## 1. One-time setup

```bash
# from repo root
cd backend
pnpm prisma:migrate:deploy       # applies migrations 0001…0007
pnpm db:seed                     # admin + 4 demo drivers + 2 demo riders + pricing rules + saved addresses
pnpm dev                         # backend on http://localhost:3000

# in another terminal
cd ../admin
pnpm dev                         # admin UI on http://localhost:3001 (or whatever Next picks)
```

Swagger UI is live at <http://localhost:3000/docs> with every endpoint.

## 2. Seeded test accounts

| Role                                       | Phone / email                         | Notes                                             |
| ------------------------------------------ | ------------------------------------- | ------------------------------------------------- |
| Admin                                      | `admin@example.com` / `ChangeMe!2026` | password login at `/login`                        |
| Rider — Priya Sen                          | `+919800000010`                       | 2 saved addresses (HOME Kalighat, WORK Salt Lake) |
| Rider — Arjun Roy                          | `+919800000011`                       | 1 saved address (New Town)                        |
| Driver — Rakesh Das (APPROVED, also rider) | `+919800000002`                       | 1 saved address (Garia)                           |
| Driver — Anita Sharma (IN_REVIEW)          | `+919800000001`                       | —                                                 |
| Driver — Pooja Singh (PENDING)             | `+919800000003`                       | —                                                 |
| Driver — Imran Khan (REJECTED)             | `+919800000004`                       | —                                                 |

Re-running `pnpm db:seed` is idempotent — addresses get wiped + re-inserted; pricing rules keep whatever you set via the admin UI.

## 3. Grabbing a token (no Firebase OTP needed)

```bash
cd backend
pnpm dev:token +919800000010        # rider Priya
pnpm dev:token +919800000002        # driver Rakesh (also a rider)
pnpm dev:token admin@example.com    # admin

# Use it like:
export TOKEN=$(pnpm -s dev:token +919800000010 | head -1)
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/users/me/profile | jq
```

The token is HS256-signed with `JWT_ACCESS_SECRET` and matches the claim shape `AuthService` issues. 15-minute TTL — re-run if it expires.

---

## Feature 1 — Address book (rider)

```bash
TOKEN=$(pnpm -s dev:token +919800000010 | head -1)
BASE=http://localhost:3000/api/v1
H="Authorization: Bearer $TOKEN"

# List (should return Priya's 2 seeded addresses, newest first)
curl -s -H "$H" "$BASE/users/me/addresses" | jq

# Create a new one
curl -s -X POST -H "$H" -H "content-type: application/json" "$BASE/users/me/addresses" -d '{
  "label": "GYM",
  "addressText": "Quest Mall, Park Circus, Kolkata 700017",
  "location": { "lat": 22.5414, "lng": 88.3676 }
}' | jq

# Patch (use the id returned above)
curl -s -X PATCH -H "$H" -H "content-type: application/json" "$BASE/users/me/addresses/<ID>" -d '{
  "label": "GYM (renamed)"
}' | jq

# Delete (204 No Content)
curl -i -X DELETE -H "$H" "$BASE/users/me/addresses/<ID>"

# Cross-user check — Arjun's token must not see Priya's rows
ARJUN=$(pnpm -s dev:token +919800000011 | head -1)
curl -s -H "Authorization: Bearer $ARJUN" "$BASE/users/me/addresses" | jq
```

## Feature 2 — Geocoding

Any authenticated user works. Results are cached in Redis for 24h — run the same query twice and watch the second response come back instantly.

```bash
# Forward geocode
curl -s -H "$H" "$BASE/maps/geocode?q=Park%20Street%2C%20Kolkata" | jq

# Reverse geocode
curl -s -H "$H" "$BASE/maps/reverse-geocode?lat=22.5526&lng=88.3527" | jq

# Negative reverse (open ocean) — should 404 NOT_FOUND
curl -s -H "$H" "$BASE/maps/reverse-geocode?lat=0&lng=0" | jq
```

If you get `503 SERVICE_UNAVAILABLE` from forward geocode: Nominatim's abuse filter rejected the User-Agent. Set `NOMINATIM_USER_AGENT` in `.env.local` to a `Mozilla/5.0 (compatible; …)` form with a real contact URL.

## Feature 3 — Route + distance

```bash
# Park Street → Salt Lake Sector V (about 8km)
curl -s -X POST -H "$H" -H "content-type: application/json" "$BASE/maps/route" -d '{
  "origin":      { "lat": 22.5526, "lng": 88.3527 },
  "destination": { "lat": 22.5867, "lng": 88.4180 }
}' | jq

# Impossible pair (Kolkata → mid-Atlantic) → 404 NO_ROUTE
curl -s -X POST -H "$H" -H "content-type: application/json" "$BASE/maps/route" -d '{
  "origin":      { "lat": 22.5526, "lng": 88.3527 },
  "destination": { "lat": 0,       "lng": -30      }
}' | jq
```

Cached in Redis for 1h; the second identical call doesn't hit OSRM.

## Feature 4 — Fare estimation

```bash
# AUTO from Park Street to Salt Lake Sector V
curl -s -X POST -H "$H" -H "content-type: application/json" "$BASE/fares/estimate" -d '{
  "origin":      { "lat": 22.5526, "lng": 88.3527 },
  "destination": { "lat": 22.5867, "lng": 88.4180 },
  "vehicleType": "AUTO"
}' | jq

# Same trip for BIKE / CNG / CAR — compare the four breakdowns
for T in BIKE AUTO CNG CAR; do
  echo "=== $T ==="
  curl -s -X POST -H "$H" -H "content-type: application/json" "$BASE/fares/estimate" -d "{
    \"origin\":      { \"lat\": 22.5526, \"lng\": 88.3527 },
    \"destination\": { \"lat\": 22.5867, \"lng\": 88.4180 },
    \"vehicleType\": \"$T\"
  }" | jq '.data | {estimatedFare, breakdown, estimatedDistance, estimatedDuration}'
done

# Min-fare floor: origin == destination → distance/time ≈ 0 → total = minimum_fare + fee + gst
curl -s -X POST -H "$H" -H "content-type: application/json" "$BASE/fares/estimate" -d '{
  "origin":      { "lat": 22.5526, "lng": 88.3527 },
  "destination": { "lat": 22.5526, "lng": 88.3527 },
  "vehicleType": "AUTO"
}' | jq
```

## Feature 5 — Pricing rules admin (API)

```bash
ADMIN=$(pnpm -s dev:token admin@example.com | head -1)
AH="Authorization: Bearer $ADMIN"

# Current active rules — should show 4 seeded rows
curl -s -H "$AH" "$BASE/admin/pricing-rules" | jq

# Raise AUTO per-km from ₹12 to ₹14 (1400 paise) — closes the prior rule and inserts a new one
curl -s -X POST -H "$AH" -H "content-type: application/json" "$BASE/admin/pricing-rules" -d '{
  "vehicleType": "AUTO",
  "baseFare":    2500,
  "perKm":       1400,
  "perMinute":   100,
  "minimumFare": 4000
}' | jq

# History for AUTO — newest first, the prior row now has effectiveTo set
curl -s -H "$AH" "$BASE/admin/pricing-rules/history?vehicleType=AUTO" | jq

# Re-run the AUTO fare estimate from Feature 4 — total should be higher now
```

## Feature 6 — Admin panel pages

Log in at <http://localhost:3001/login> with `admin@example.com` / `ChangeMe!2026`.

1. **Sidebar → Pricing** (`/pricing`)
   - Table shows one row per vehicle type with the current rate.
   - Click **Edit** on AUTO → change per km to ₹14 → **Save new rule**.
   - The table refreshes and shows the new rate; the _Effective from_ column is "just now".
2. **Pricing → View history →** (`/pricing/history`)
   - Pick AUTO from the selector; the row you just changed is at the top with **active**, the prior row has an end timestamp.
   - The **Changed by** column shows the admin user.
3. **Sidebar → Drivers → Rakesh Das**
   - Click **Saved addresses →** in the header.
4. **Saved addresses page** (`/users/usr_…/addresses`)
   - Driver's name + phone in the header.
   - Address list (Rakesh's HOME at Garia).
   - **Feature 7 verified here too** — Leaflet map on the same page with a pin at the address location, popup shows label + text.
5. Repeat for **Priya** (one of the demo riders). You'll need her `publicId` — grab it from the seed output or:
   ```bash
   pnpm dev:token +919800000010   # writes "user: usr_… roles: RIDER" to stderr
   ```
   Then visit `http://localhost:3001/users/<usr_publicId>/addresses` — you should see two pins auto-fitting to bounds (Kalighat + Salt Lake).

## Feature 7 — Leaflet `<Map>` component

Verified inline with Feature 6 (the addresses page). What to look at specifically:

- Map tiles load from OpenStreetMap with attribution at the bottom-right.
- Multiple markers → viewport auto-fits to include them all.
- Clicking a marker opens a popup with the address label + text.
- Markers render with the default Leaflet pin icon (not blank squares — that's the webpack-icon fix paying off).

## Sprint 3 Definition of Done checklist

- [x] All endpoints functional and Swagger-documented — visit `/docs`.
- [x] Pricing rule changes are atomic + audited — Feature 5 walkthrough.
- [x] Geocode/route caching cuts external calls — run the same call twice; second is sub-50ms. Verify in Redis:
  ```bash
  redis-cli KEYS 'geocode:*' && redis-cli KEYS 'route:*'
  ```
- [x] Nominatim rate limiter prevents 429s — the provider spaces outbound calls ≥1.1s apart.
- [x] Fare math unit tests — `cd backend && pnpm test -t FaresService`.
- [ ] Git tag `v0.3.0-sprint-3` pushed (final step once you're happy).

## Troubleshooting

- **`No user found for <phone>`** from `pnpm dev:token` — run `pnpm db:seed`.
- **`401 UNAUTHENTICATED`** on rider endpoints — the access token is HS256-signed with `JWT_ACCESS_SECRET`; make sure the backend you're hitting reads the _same_ `.env.local`. Token TTL is 15 minutes; re-run `pnpm dev:token`.
- **Map shows tiles but no markers** — hard refresh the page; the icon-URL patch runs once per browser session.
- **`503 SERVICE_UNAVAILABLE` from `/maps/*`** — Nominatim/OSRM public demos are best-effort. Wait a minute and retry, or check the backend logs for the upstream HTTP status.
