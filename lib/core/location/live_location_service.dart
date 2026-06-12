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
class LiveLocationService {
  LiveLocationService();

  static const Duration pingInterval = Duration(seconds: 5);

  final StreamController<LocationSample> _samples =
      StreamController<LocationSample>.broadcast();
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  Position? _last;

  /// Samples at roughly [pingInterval] while the service is running.
  Stream<LocationSample> get samples => _samples.stream;

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
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen((p) => _last = p, onError: (_) {});

    // Seed an immediate fix so the first ping doesn't wait a whole interval.
    try {
      _last ??= await Geolocator.getCurrentPosition();
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
  }

  void _emit() {
    final p = _last;
    if (p == null) return;
    _samples.add(
      LocationSample(
        lat: p.latitude,
        lng: p.longitude,
        speed: p.speed.isFinite ? p.speed : null,
        bearing: p.heading.isFinite ? p.heading : null,
        recordedAt: DateTime.now().toUtc(),
      ),
    );
  }

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: pingInterval,
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
