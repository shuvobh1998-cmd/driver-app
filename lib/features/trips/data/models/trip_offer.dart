import '../../../onboarding_kyc/data/models/onboarding_enums.dart';
import 'trip.dart';

/// An incoming trip offer pushed over the socket as `trip.offered`:
/// `{ offerId, rideRequestId, vehicleType, pickup: { lat, lng }, distanceMeters,
/// expiresAt }`. This is a notification only — the authoritative trip is fetched
/// over REST once the offer is accepted.
class TripOffer {
  const TripOffer({
    required this.offerId,
    required this.rideRequestId,
    required this.vehicleType,
    required this.pickup,
    required this.distanceMeters,
    required this.expiresAt,
    required this.receivedAt,
  });

  /// Public id (`off_*`) used on accept / decline.
  final String offerId;
  final String rideRequestId;
  final VehicleType vehicleType;
  final TripPlace pickup;

  /// Straight-line distance from the driver to the pickup, in metres.
  final int? distanceMeters;

  /// When the offer auto-expires; the countdown ring runs to this instant.
  final DateTime expiresAt;

  /// When the client received the offer — the countdown's full duration.
  final DateTime receivedAt;

  /// Seconds left before the offer expires (never negative).
  int get secondsLeft {
    final left = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    return left < 0 ? 0 : left;
  }

  /// Total countdown window in seconds, for the ring's denominator.
  int get totalSeconds {
    final total = expiresAt.difference(receivedAt).inSeconds;
    return total <= 0 ? 1 : total;
  }

  bool get isExpired => secondsLeft <= 0;

  /// Builds an offer from a loosely-typed socket payload, tolerating missing or
  /// oddly-typed fields rather than throwing inside the socket handler.
  static TripOffer? tryParse(Object? data) {
    if (data is! Map) return null;
    final offerId = data['offerId'];
    final pickupRaw = data['pickup'];
    if (offerId is! String || pickupRaw is! Map) return null;

    final lat = _toDouble(pickupRaw['lat']);
    final lng = _toDouble(pickupRaw['lng']);
    if (lat == null || lng == null) return null;

    final expires = DateTime.tryParse('${data['expiresAt']}')?.toUtc();
    return TripOffer(
      offerId: offerId,
      rideRequestId: '${data['rideRequestId'] ?? ''}',
      vehicleType: _vehicleType('${data['vehicleType'] ?? ''}'),
      pickup: TripPlace(
        lat: lat,
        lng: lng,
        address: pickupRaw['address'] as String?,
      ),
      distanceMeters: _toInt(data['distanceMeters']),
      // Default to a 15s window if the server omits/expires field is malformed.
      expiresAt:
          expires ?? DateTime.now().toUtc().add(const Duration(seconds: 15)),
      receivedAt: DateTime.now().toUtc(),
    );
  }

  static double? _toDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v');

  static int? _toInt(Object? v) =>
      v is num ? v.round() : int.tryParse('$v'.split('.').first);

  static VehicleType _vehicleType(String raw) => switch (raw) {
    'BIKE' => VehicleType.bike,
    'AUTO' => VehicleType.auto,
    'CNG' => VehicleType.cng,
    'CAR' => VehicleType.car,
    _ => VehicleType.unknown,
  };
}
