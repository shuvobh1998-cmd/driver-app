import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// A single location reading destined for `POST /drivers/me/location`.
class LocationSample {
  const LocationSample({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.speed,
    this.bearing,
  });

  final double lat;
  final double lng;
  final DateTime recordedAt;
  final double? speed;
  final double? bearing;
}

/// Streams the driver's location while they are online (~5s cadence), including
/// when backgrounded — a foreground-service notification keeps the OS from
/// killing the stream. The actual upload + offline queue/flush live in the
/// pump (`DriverHomeController`); this service only produces samples.
///
/// A position [Stream] keeps a fresh fix (and powers the foreground service);
/// a separate periodic timer emits a [LocationSample] every [pingInterval] from
/// the latest fix, so pings keep a steady cadence even while stationary.
/// [fixes] forwards every raw fix (~[fixInterval]) for the faster live
/// `trip.location` stream the rider's map follows.
class LiveLocationService {
  LiveLocationService();

  static const Duration pingInterval = Duration(seconds: 5);

  /// How often the OS is asked for a fresh fix.
  static const Duration fixInterval = Duration(seconds: 3);

  /// How long [start] waits for its seed fix before falling back to the last
  /// known position; the stream supplies fixes after that either way.
  static const Duration seedFixTimeout = Duration(seconds: 10);

  final StreamController<LocationSample> _samples =
      StreamController<LocationSample>.broadcast();
  final StreamController<LocationSample> _fixes =
      StreamController<LocationSample>.broadcast();
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  Position? _last;

  /// Samples at roughly [pingInterval] while the service is running.
  Stream<LocationSample> get samples => _samples.stream;

  /// Every fix as the OS delivers it — about every [fixInterval] on Android,
  /// often faster on iOS, so consumers throttle to their own cadence.
  Stream<LocationSample> get fixes => _fixes.stream;

  bool get isRunning => _timer != null;

  /// Ensures we hold (or can request) location permission before going online.
  /// Requests escalate from whileInUse to always so background pings survive.
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Begins streaming. Idempotent: a second call while running is a no-op.
  Future<void> start() async {
    if (isRunning) return;
    // Drop a stream left behind by an earlier start() that threw part-way.
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(locationSettings: _settings())
        .listen((p) {
          _last = p;
          _fixes.add(_toSample(p));
        }, onError: (_) {});

    // Seed an immediate fix so the first ping doesn't wait a whole interval.
    // Bounded: with no GPS fix getCurrentPosition can wait forever, which would
    // hang go-online (and the home screen's load) on the spinner.
    try {
      _last ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: seedFixTimeout),
      );
    } catch (_) {
      _last ??= await Geolocator.getLastKnownPosition();
    }
    _emit();
    _timer = Timer.periodic(pingInterval, (_) => _emit());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _last = null;
  }

  void dispose() {
    stop();
    _samples.close();
    _fixes.close();
  }

  void _emit() {
    final p = _last;
    if (p == null) return;
    _samples.add(_toSample(p));
  }

  static LocationSample _toSample(Position p) => LocationSample(
    lat: p.latitude,
    lng: p.longitude,
    speed: p.speed.isFinite ? p.speed : null,
    bearing: p.heading.isFinite ? p.heading : null,
    recordedAt: DateTime.now().toUtc(),
  );

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: fixInterval,
        // Keeps location flowing while backgrounded and shows the required
        // ongoing notification (acceptance: pings continue when backgrounded).
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'You are online',
          notificationText: 'Sharing your location to receive trips',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }
}
