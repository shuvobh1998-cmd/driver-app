import 'package:json_annotation/json_annotation.dart';

import 'earnings_enums.dart';

part 'payout_method.g.dart';

/// The driver's saved payout destination (`GET /drivers/me/payout-method`). The
/// [accountNumber] arrives already masked from the backend (e.g. `••••6789`).
@JsonSerializable(createToJson: false)
class PayoutMethod {
  const PayoutMethod({
    required this.methodType,
    this.upiId,
    this.accountName,
    this.accountNumber,
    this.ifsc,
  });

  @JsonKey(unknownEnumValue: PayoutMethodType.unknown)
  final PayoutMethodType methodType;

  final String? upiId;
  final String? accountName;

  /// Masked account number (display only).
  final String? accountNumber;
  final String? ifsc;

  /// A one-line, human display of where money goes.
  String get display => switch (methodType) {
    PayoutMethodType.upi => upiId ?? 'UPI',
    PayoutMethodType.bank => [
      if (accountName != null) accountName,
      accountNumber,
    ].whereType<String>().join(' · '),
    PayoutMethodType.unknown => '—',
  };

  factory PayoutMethod.fromJson(Map<String, dynamic> json) =>
      _$PayoutMethodFromJson(json);
}

/// Body for `PUT /drivers/me/payout-method`. Send the full unmasked account
/// number for BANK, or the [upiId] for UPI.
@JsonSerializable(includeIfNull: false, createFactory: false)
class UpdatePayoutMethod {
  const UpdatePayoutMethod.upi({required this.upiId})
    : methodType = PayoutMethodType.upi,
      accountName = null,
      accountNumber = null,
      ifsc = null;

  const UpdatePayoutMethod.bank({
    required this.accountName,
    required this.accountNumber,
    required this.ifsc,
  }) : methodType = PayoutMethodType.bank,
       upiId = null;

  @JsonKey(toJson: _methodTypeToJson)
  final PayoutMethodType methodType;
  final String? upiId;
  final String? accountName;
  final String? accountNumber;
  final String? ifsc;

  Map<String, dynamic> toJson() => _$UpdatePayoutMethodToJson(this);
}

String _methodTypeToJson(PayoutMethodType type) => type.wireValue;
