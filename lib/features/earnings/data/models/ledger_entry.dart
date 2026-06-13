import 'package:json_annotation/json_annotation.dart';

import 'earnings_enums.dart';

part 'ledger_entry.g.dart';

/// One line in the wallet ledger (`GET /drivers/me/wallet/ledger`). [amount] and
/// [balanceAfter] are integer **paise**; [direction] says whether it added to or
/// drew from the balance.
@JsonSerializable(createToJson: false)
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.direction,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.tripId,
    this.payoutId,
    this.note,
  });

  final String id;

  @JsonKey(unknownEnumValue: LedgerDirection.unknown)
  final LedgerDirection direction;

  @JsonKey(unknownEnumValue: LedgerReason.unknown)
  final LedgerReason reason;

  /// Movement amount in paise (always positive; sign comes from [direction]).
  final int amount;

  /// Wallet balance after this entry was applied, in paise.
  final int balanceAfter;

  /// The trip this entry relates to, when applicable (`trp_*`).
  final String? tripId;

  /// The payout this entry relates to, when applicable (`pyt_*`).
  final String? payoutId;

  /// Free-text note from the backend (e.g. "Trip earning (UPI)").
  final String? note;

  final DateTime createdAt;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) =>
      _$LedgerEntryFromJson(json);
}
