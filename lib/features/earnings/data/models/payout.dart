import 'package:json_annotation/json_annotation.dart';

import 'earnings_enums.dart';

part 'payout.g.dart';

/// A withdrawal request (`POST /drivers/me/payouts/request`, `GET …/payouts[/:id]`).
/// [amount] is integer **paise**. [reference] is the bank/UPI UTR once paid.
@JsonSerializable(createToJson: false)
class Payout {
  const Payout({
    required this.id,
    required this.amount,
    required this.methodType,
    required this.status,
    required this.requestedAt,
    this.upiId,
    this.notes,
    this.reference,
    this.processedAt,
  });

  final String id;

  /// Withdrawal amount in paise.
  final int amount;

  @JsonKey(unknownEnumValue: PayoutMethodType.unknown)
  final PayoutMethodType methodType;

  final String? upiId;

  @JsonKey(unknownEnumValue: PayoutStatus.unknown)
  final PayoutStatus status;

  final String? notes;

  /// Payment reference (UTR) once the payout is settled.
  final String? reference;

  final DateTime requestedAt;
  final DateTime? processedAt;

  factory Payout.fromJson(Map<String, dynamic> json) => _$PayoutFromJson(json);
}
