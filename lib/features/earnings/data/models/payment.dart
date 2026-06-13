import 'package:json_annotation/json_annotation.dart';

import '../../../trips/data/models/trip_enums.dart';

part 'payment.g.dart';

/// A trip's payment record, returned by
/// `POST /trips/:id/payment/cash-collected`. All money fields are integer
/// **paise**: [amount] is the fare, [commission] + [gst] are what the driver
/// owes the platform on a cash trip, and [driverEarning] is the net kept.
@JsonSerializable(createToJson: false)
class Payment {
  const Payment({
    required this.id,
    required this.tripId,
    required this.method,
    required this.amount,
    required this.commission,
    required this.gst,
    required this.driverEarning,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  final String id;
  final String tripId;

  @JsonKey(unknownEnumValue: PaymentMethod.unknown)
  final PaymentMethod method;

  final int amount;
  final int commission;
  final int gst;
  final int driverEarning;
  final String currency;

  @JsonKey(unknownEnumValue: PaymentStatus.unknown)
  final PaymentStatus status;

  final DateTime? paidAt;
  final DateTime createdAt;

  /// What the platform takes on a cash trip (commission + GST), in paise.
  int get platformCut => commission + gst;

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);
}
