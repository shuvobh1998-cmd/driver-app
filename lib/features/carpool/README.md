# carpool

D6 — Carpool + chat: post/manage scheduled trips, bookings, 1:1 chat.

Layers:
- `data/` — `CarpoolApi` (scheduled trips + bookings) and `ChatApi`, their models and providers.
- `presentation/` — screens (my trips, post/edit trip, trip detail + bookings, chat threads + thread), controllers and widgets.

## Screens
- **My carpool trips** — paginated, status-filtered list of the driver's posted trips; FAB to post.
- **Post a trip** — route (map pin + address), departure, vehicle, seats, price/seat, AC + gender prefs, notes.
- **Edit trip** — mutable fields while OPEN with no bookings.
- **Trip detail** — summary + lifecycle actions (start / complete / cancel) and the bookings list with no-show + chat.
- **Chats** — thread list with live unread counts.
- **Chat thread** — 1:1 conversation with a composer; live via `chat.message.received`.

## Endpoints
`POST /scheduled-trips` · `GET /scheduled-trips/me` · `GET/PATCH /scheduled-trips/:id` ·
`POST /scheduled-trips/:id/start|complete|cancel` · `GET /scheduled-trips/:id/bookings` ·
`POST /bookings/:id/no-show` · `POST /chats/messages` · `GET /chats/threads` ·
`GET /chats/threads/:otherUserId/messages` · `POST /chats/threads/:otherUserId/read`.

## Realtime
`chat.message.received` is consumed by the chat controllers while their screens are
mounted — **WS is a notifier, REST is the truth**, so each event triggers a re-fetch /
append reconciled against the server.

See `docs/DRIVER_APP_SPRINT_PLAN.md` (D6).
