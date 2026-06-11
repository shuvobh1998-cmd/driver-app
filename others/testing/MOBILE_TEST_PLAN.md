# Mobile Test Plan

## Layers

### Widget tests (`test/`)

- Form validation (signup, login, profile edit)
- Reusable widgets (VehicleTypeCard, MoneyDisplay, OTP input)
- Run on every PR via `flutter test`

### Integration tests (`integration_test/`)

- Full screen flows with mocked API
- Critical paths per [`TESTING_STRATEGY.md`](TESTING_STRATEGY.md)
- Run on PR (slow — runs against emulator)

### Manual on real device

- Before every APK / IPA ship
- See manual smoke checklist below

## Manual smoke (run before every TestFlight / Internal Testing upload)

Time: ~30 min. Use Android phone + iPhone (or simulator) + a fresh install.

### First launch

- [ ] Splash → login screen (no token yet)
- [ ] Location permission requested when expected
- [ ] App config loaded (vehicle types appear in booking flow later)

### Signup flow

- [ ] Enter test phone → OTP arrives (or test number `+91 99999XXXXX` → `123456`)
- [ ] Submit OTP → profile setup screen
- [ ] Fill all fields → password validation works (6 digits)
- [ ] Submit → land on rider home logged in

### Login flow

- [ ] Logout
- [ ] Enter phone + password → land on home
- [ ] Force-stop app → reopen → still logged in (refresh token)
- [ ] Forgot password → OTP → reset → log in with new password

### Rider booking (after M04)

- [ ] Tap "Where to?" → autocomplete works as you type
- [ ] Pick pickup + drop → fare quote sheet shows 4 vehicle types
- [ ] Pick AUTO → "Finding driver"
- [ ] (With test driver online from another device) → "Matched" screen shows
- [ ] Cancel works pre-pickup

### Trip lifecycle (after M05)

- [ ] Live driver pin moves smoothly on rider map
- [ ] Driver enters OTP → trip starts
- [ ] Driver ends trip → rating screen
- [ ] Rate 5 stars → submit → back to home
- [ ] Trip in history

### Driver flow (after M03 + M05)

- [ ] KYC upload all 4 docs (camera + gallery)
- [ ] Vehicle add + photo
- [ ] Go online → admin sees pin
- [ ] Receive offer → accept
- [ ] Navigate to pickup, mark arrived
- [ ] Start trip (enter OTP from rider)
- [ ] End trip → rate rider
- [ ] Cash collected works

### Payments (after M06)

- [ ] UPI test payment via Razorpay test mode
- [ ] Driver wallet balance updates
- [ ] Payout request → admin marks paid → balance debits

### Carpool (after M07)

- [ ] Driver posts a trip
- [ ] Rider searches → finds → books
- [ ] Chat exchange works real-time

### Notifications (after M08)

- [ ] Push received in foreground (in-app banner)
- [ ] Push received in background (system tray)
- [ ] Tap push → opens correct screen

### Safety (after M08)

- [ ] SOS button: hold 2s → confirmation → SMS sent to emergency contact
- [ ] Share trip with phone number → recipient opens link in browser → masked tracker visible

### Settings (after M08)

- [ ] Change language to Bengali → main screens translate
- [ ] Logout from all other devices works
- [ ] Delete account → 30-day countdown banner appears
- [ ] Cancel deletion within window

### Edge cases

- [ ] App backgrounded for 1h → resumes correctly
- [ ] Network drop during ride → app shows offline banner, syncs on reconnect
- [ ] Low battery on driver phone (location pings continue?)
- [ ] Killed and reopened during active trip → trip state recovered
- [ ] Phone rotated → no crash (lock to portrait OK if simpler)

## Device matrix

| Device                               | Why                                   |
| ------------------------------------ | ------------------------------------- |
| Android phone (any OEM, Android 12+) | Primary user base                     |
| iPhone (latest stable iOS)           | iOS users                             |
| Low-end Android (3GB RAM)            | Driver phones are often older         |
| Tablet                               | Confirm responsive (or lock to phone) |

## Performance baselines

- Cold start < 3s
- Map first paint < 1s with cached tiles
- Booking flow → fare quote < 2s
- Push received → screen response < 500ms
- Battery use during 1h drive (online) < 15% additional drain

## CI workflow snippet

`.github/workflows/mobile-test.yml`:

```yaml
name: Mobile test
on: pull_request
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x' }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --debug
```
