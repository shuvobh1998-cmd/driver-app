import 'package:json_annotation/json_annotation.dart';

import '../../../onboarding_kyc/data/models/onboarding_enums.dart';
import 'carpool_enums.dart';

part 'scheduled_trip.g.dart';

/// A `{lat, lng}` point, per the handoff location convention.
@JsonSerializable()
class LatLngPoint {
  const LatLngPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory LatLngPoint.fromJson(Map<String, dynamic> json) =>
      _$LatLngPointFromJson(json);
  Map<String, dynamic> toJson() => _$LatLngPointToJson(this);
}

/// Seat preferences a driver sets when posting a carpool trip.
@JsonSerializable()
class TripPreferences {
  const TripPreferences({this.ac, this.gender});

  /// Air-conditioned ride.
  final bool? ac;

  @JsonKey(unknownEnumValue: GenderPreference.any)
  final GenderPreference? gender;

  factory TripPreferences.fromJson(Map<String, dynamic> json) =>
      _$TripPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$TripPreferencesToJson(this);
}

/// The trip's driver, as embedded in a [ScheduledTrip]. (The driver viewing
/// their own posted trips is themselves, but the field is modelled for parity
/// with the rider-facing payload.)
@JsonSerializable(createToJson: false)
class CarpoolDriverSummary {
  const CarpoolDriverSummary({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.ratingAvg,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final double? ratingAvg;

  factory CarpoolDriverSummary.fromJson(Map<String, dynamic> json) =>
      _$CarpoolDriverSummaryFromJson(json);
}

/// The vehicle a carpool trip runs on, embedded in a [ScheduledTrip].
@JsonSerializable(createToJson: false)
class CarpoolVehicleSummary {
  const CarpoolVehicleSummary({
    required this.type,
    this.make,
    this.model,
    this.color,
  });

  @JsonKey(unknownEnumValue: VehicleType.unknown)
  final VehicleType type;
  final String? make;
  final String? model;
  final String? color;

  /// e.g. "Maruti Swift · White" — falls back to the vehicle type.
  String get display {
    final parts = [
      if (make != null && make!.isNotEmpty) make,
      if (model != null && model!.isNotEmpty) model,
    ].join(' ');
    final name = parts.isEmpty ? type.label : parts;
    return color != null && color!.isNotEmpty ? '$name · $color' : name;
  }

  factory CarpoolVehicleSummary.fromJson(Map<String, dynamic> json) =>
      _$CarpoolVehicleSummaryFromJson(json);
}

/// A posted carpool trip (`POST/GET/PATCH /scheduled-trips…`). [pricePerSeat] is
/// integer **paise**; [departureAt] is ISO-8601 UTC.
@JsonSerializable(createToJson: false)
class ScheduledTrip {
  const ScheduledTrip({
    required this.id,
    required this.driver,
    required this.vehicle,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.totalSeats,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.preferences,
    required this.status,
    required this.createdAt,
    this.originAddress,
    this.destAddress,
    this.notes,
    this.routeMatchMeters,
  });

  /// Public id (`sct_*`) used in every carpool route.
  final String id;

  final CarpoolDriverSummary driver;
  final CarpoolVehicleSummary vehicle;

  final LatLngPoint origin;
  final String? originAddress;
  final LatLngPoint destination;
  final String? destAddress;

  final DateTime departureAt;

  final int totalSeats;
  final int availableSeats;

  /// Price per seat in paise.
  final int pricePerSeat;

  final String? notes;
  final TripPreferences preferences;

  @JsonKey(unknownEnumValue: ScheduledTripStatus.unknown)
  final ScheduledTripStatus status;

  /// How far off the requested route a search match sits (search only).
  final int? routeMatchMeters;

  final DateTime createdAt;

  /// Seats already taken.
  int get bookedSeats => totalSeats - availableSeats;

  /// Editable only while OPEN and nothing is booked yet.
  bool get isEditable => status.isOpen && bookedSeats == 0;

  String get originLabel => originAddress ?? _coords(origin);
  String get destLabel => destAddress ?? _coords(destination);

  static String _coords(LatLngPoint p) =>
      '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';

  factory ScheduledTrip.fromJson(Map<String, dynamic> json) =>
      _$ScheduledTripFromJson(json);
}
