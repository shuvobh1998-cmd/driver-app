# notifications

D7 — Notifications, safety & launch: FCM inbox, SOS, live-share, support, help center.

Layers:
- `data/` — APIs (`NotificationsApi`, `SafetyApi`, `SupportApi`, `ContentApi`), models, providers, the FCM `DeviceRegistrar`.
- `presentation/` — screens, controllers and widgets.

## Screens
- **Notifications inbox** — paginated, unread badge on home, deep-link tap, mark one / all read; live via `notification.received`.
- **Share my ride** — create a live-tracking link (optionally SMS'd to phones), list + revoke active shares.
- **Emergency SOS** — hold-to-confirm sheet on the active trip; alerts emergency contacts + safety team.
- **Support** — my tickets, ticket thread + reply, open a ticket, report a lost item.
- **Help center** — FAQ grouped by category + legal documents (terms, privacy, driver agreement).

## Infra
- `DeviceRegistrar` registers the FCM token (`POST /users/me/device-tokens`) on sign-in and
  unregisters on sign-out; kept alive at the app root by `TripOfferGate`. Best-effort — any
  Firebase/permission failure is swallowed.
- Unread count + inbox subscribe to the shared socket's `notification.received` and reconcile
  against REST.

## Endpoints
`GET /notifications` · `/unread-count` · `POST /notifications/:id/read` · `/read-all` ·
`POST/DELETE /users/me/device-tokens` · `POST /trips/:id/sos` · `/share` · `GET /trips/:id/shares` ·
`DELETE /trips/:id/share/:shareId` · `POST /support/tickets` · `/lost-item` ·
`GET /support/tickets/me` · `/tickets/:id` · `POST /tickets/:id/messages` ·
`GET /content/faq` · `/content/legal/:slug`.

See `docs/DRIVER_APP_SPRINT_PLAN.md` (D7).
