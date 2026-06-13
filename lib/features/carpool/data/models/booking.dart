import 'package:json_annotation/json_annotation.dart';

import 'carpool_enums.dart';
import 'scheduled_trip.dart';

part 'booking.g.dart';

/// The rider on a booking, as shown to the trip's driver.
@JsonSerializable(createToJson: false)
class BookingRider {
  const BookingRider({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  /// Display name, falling back to "Rider" when the backend masks it.
  String get name {
    final full = [
      if (firstName != null && firstName!.isNotEmpty) firstName,
      if (lastName != null && lastName!.isNotEmpty) lastName,
    ].join(' ');
    return full.isEmpty ? 'Rider' : full;
  }

  factory BookingRider.fromJson(Map<String, dynamic> json) =>
      _$BookingRiderFromJson(json);
}

/// A booking row (`GET /scheduled-trips/:id/bookings`, `POST …/no-show`).
/// [amount] and [refundAmount] are integer **paise**.
@JsonSerializable(createToJson: false)
class Booking {
  const Booking({
    required this.id,
    required this.scheduledTripId,
    required this.seats,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.pickup,
    this.pickupAddress,
    this.dropAddress,
    this.refundAmount,
    this.rider,
  });

  final String id;
  final String scheduledTripId;
  final int seats;

  final LatLngPoint? pickup;
  final String? pickupAddress;
  final String? dropAddress;

  /// Total seat fare in paise.
  final int amount;

  @JsonKey(unknownEnumValue: BookingStatus.unknown)
  final BookingStatus status;

  @JsonKey(unknownEnumValue: BookingPaymentStatus.unknown)
  final BookingPaymentStatus paymentStatus;

  /// Amount refunded in paise, when the booking was cancelled/refunded.
  final int? refundAmount;

  final BookingRider? rider;

  final DateTime createdAt;

  String get pickupLabel =>
      pickupAddress ??
      (pickup == null
          ? 'Pickup not set'
          : '${pickup!.lat.toStringAsFixed(5)}, ${pickup!.lng.toStringAsFixed(5)}');

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);
}
