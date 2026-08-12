# onboarding_kyc

D2 — KYC + Vehicle submission: upgrade-to-driver, document checklist, vehicle registration, approval status.

Layers:
- `data/` — repositories + API.
- `domain/` — entities + use-cases.
- `presentation/` — screens + controllers + widgets.

Filled in during this feature's sprint. See `docs/DRIVER_APP_SPRINT_PLAN.md`.

## Uploads + Cloudinary

Backend storage is Cloudinary (backend Sprint 11) behind **unchanged endpoint
contracts** — the multipart upload code here needs no provider-specific changes.

What does matter to this feature:

- **KYC document URLs are signed with a 1h TTL** (Cloudinary authenticated delivery).
  Never cache `KycDocument.fileUrl` past that; refetch
  `GET /drivers/me/kyc/documents` for a fresh URL and handle render failures with a
  retry rather than a dead thumbnail.
- **Vehicle photos are public CDN URLs** (`w_1024,h_768,c_fit,f_auto,q_auto`) — stable
  and safe to cache.
- **5MB server cap** on multipart. Guard client-side before uploading.
- **PDFs are accepted** for KYC docs (`application/pdf`) and must skip image compression.

D9 covers the client-side hardening for all of the above.
