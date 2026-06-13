import 'package:json_annotation/json_annotation.dart';

import '../../../onboarding_kyc/data/models/onboarding_enums.dart';
import 'trip_enums.dart';

part 'trip.g.dart';

/// A pickup or drop location: `{lat, lng}` plus an optional human address,
/// per the handoff location convention.
@JsonSerializable(createToJson: false)
class TripPlace {
  const TripPlace({required this.lat, required this.lng, this.address});

  final double lat;
  final double lng;
  final String? address;

  /// What to show as the place name, falling back to coordinates.
  String get display =>
      address ?? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  factory TripPlace.fromJson(Map<String, dynamic> json) =>
      _$TripPlaceFromJson(json);
}

/// The itemised fare, all components in integer **paise**.
@JsonSerializable(createToJson: false)
class FareBreakdown {
  const FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.platformFee,
    required this.gst,
    required this.total,
  });

  final int baseFare;
  final int distanceFare;
  final int timeFare;
  final int platformFee;
  final int gst;
  final int total;

  factory FareBreakdown.fromJson(Map<String, dynamic> json) =>
      _$FareBreakdownFromJson(json);
}

/// A driver-facing trip, from `GET /drivers/me/trips[/current]`, `GET /trips/:id`,
/// and every lifecycle POST (each returns the updated [TripDto]).
///
/// Money fields are integer paise; timestamps are ISO-8601 UTC. `startOtp` is
/// only ever populated for the rider, so it is always null here — the driver
/// types the OTP the rider reads aloud.
@JsonSerializable(createToJson: false)
class Trip {
  const Trip({
    required this.publicId,
    required this.status,
    required this.vehicleType,
    required this.pickup,
    required this.drop,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.estimatedFare,
    required this.createdAt,
    this.actualDistance,
    this.actualDuration,
    this.totalFare,
    this.fareBreakdown,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.endedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.driverRating,
    this.driverRatingComment,
    this.riderRating,
    this.riderRatingComment,
  });

  /// Public id (`trp_*`) used in every driver route.
  final String publicId;

  @JsonKey(unknownEnumValue: TripStatus.unknown)
  final TripStatus status;

  @JsonKey(unknownEnumValue: VehicleType.unknown)
  final VehicleType vehicleType;

  final TripPlace pickup;
  final TripPlace drop;

  @JsonKey(unknownEnumValue: PaymentMethod.unknown)
  final PaymentMethod paymentMethod;

  @JsonKey(unknownEnumValue: PaymentStatus.unknown)
  final PaymentStatus paymentStatus;

  /// Fare snapshot at request time (paise).
  final int estimatedFare;

  /// Actual distance travelled in metres; null until the trip ends.
  final int? actualDistance;

  /// Actual duration in seconds; null until the trip ends.
  final int? actualDuration;

  /// Final fare in paise; null until the trip ends.
  final int? totalFare;

  final FareBreakdown? fareBreakdown;

  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? cancelledAt;

  @JsonKey(unknownEnumValue: CancelActor.unknown)
  final CancelActor? cancelledBy;
  final String? cancelReason;

  /// Rating (1–5) the rider gave the driver.
  final int? driverRating;
  final String? driverRatingComment;

  /// Rating (1–5) the driver gave the rider — null until [rateRider].
  final int? riderRating;
  final String? riderRatingComment;

  final DateTime createdAt;

  /// True once the driver has already rated this rider (guards a re-rate).
  bool get isRated => riderRating != null;

  /// The fare to display: the final fare once known, otherwise the estimate.
  int get displayFare => totalFare ?? estimatedFare;

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
}

/// Result of accepting an offer (`POST /drivers/me/trip-offers/:id/accept`):
/// the id and status of the trip the accept created.
@JsonSerializable(createToJson: false)
class AcceptOfferResult {
  const AcceptOfferResult({required this.tripPublicId, required this.status});

  final String tripPublicId;

  @JsonKey(unknownEnumValue: TripStatus.unknown)
  final TripStatus status;

  factory AcceptOfferResult.fromJson(Map<String, dynamic> json) =>
      _$AcceptOfferResultFromJson(json);
}

/// A filed trip problem report (`POST /trips/:id/report`).
@JsonSerializable(createToJson: false)
class TripReport {
  const TripReport({
    required this.publicId,
    required this.tripId,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  final String publicId;
  final String tripId;

  @JsonKey(unknownEnumValue: ReportCategory.other)
  final ReportCategory category;
  final String description;
  final String status;
  final DateTime createdAt;

  factory TripReport.fromJson(Map<String, dynamic> json) =>
      _$TripReportFromJson(json);
}
