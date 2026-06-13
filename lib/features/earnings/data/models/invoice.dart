import 'package:json_annotation/json_annotation.dart';

import '../../../trips/data/models/trip_enums.dart';

part 'invoice.g.dart';

/// One line of a tax invoice (`GET /trips/:id/invoice`). [amount] is paise.
@JsonSerializable(createToJson: false)
class InvoiceLine {
  const InvoiceLine({required this.label, required this.amount});

  final String label;
  final int amount;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) =>
      _$InvoiceLineFromJson(json);
}

/// A trip's tax invoice (`GET /trips/:id/invoice`). [lines] + [total] itemise
/// the fare in paise; the matching PDF is at `…/invoice.pdf`.
@JsonSerializable(createToJson: false)
class Invoice {
  const Invoice({
    required this.invoiceNumber,
    required this.tripId,
    required this.companyName,
    required this.companyAddress,
    required this.gstin,
    required this.vehicleType,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.lines,
    required this.total,
    required this.totalFormatted,
    required this.currency,
    this.pickupAddress,
    this.dropAddress,
    this.distanceMeters,
    this.durationSeconds,
    this.issuedAt,
  });

  final String invoiceNumber;
  final String tripId;
  final String companyName;
  final String companyAddress;
  final String gstin;
  final String? pickupAddress;
  final String? dropAddress;
  final String vehicleType;
  final int? distanceMeters;
  final int? durationSeconds;

  @JsonKey(unknownEnumValue: PaymentMethod.unknown)
  final PaymentMethod paymentMethod;

  @JsonKey(unknownEnumValue: PaymentStatus.unknown)
  final PaymentStatus paymentStatus;

  final List<InvoiceLine> lines;

  /// Invoice total in paise.
  final int total;

  /// Server-formatted total (e.g. "₹125.50") — handy as a fallback.
  final String totalFormatted;
  final String currency;
  final DateTime? issuedAt;

  factory Invoice.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFromJson(json);
}
