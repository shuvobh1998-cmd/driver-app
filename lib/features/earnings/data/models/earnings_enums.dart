import 'package:json_annotation/json_annotation.dart';

import '../../../../design_system/design_system.dart';

/// Direction of a wallet ledger entry — money in (CREDIT) or out (DEBIT).
@JsonEnum()
enum LedgerDirection {
  @JsonValue('CREDIT')
  credit,
  @JsonValue('DEBIT')
  debit,
  unknown;

  bool get isCredit => this == credit;

  /// `+` for credits, `−` for debits — prefixes the formatted amount.
  String get sign => switch (this) {
    LedgerDirection.credit => '+',
    LedgerDirection.debit => '−',
    LedgerDirection.unknown => '',
  };
}

/// Why a ledger entry was created. Drives the row's label + icon.
@JsonEnum()
enum LedgerReason {
  @JsonValue('TRIP_EARNING')
  tripEarning,
  @JsonValue('TRIP_COMMISSION')
  tripCommission,
  @JsonValue('PAYOUT')
  payout,
  @JsonValue('PAYOUT_REVERSAL')
  payoutReversal,
  @JsonValue('ADJUSTMENT')
  adjustment,
  unknown;

  String get label => switch (this) {
    LedgerReason.tripEarning => 'Trip earning',
    LedgerReason.tripCommission => 'Commission',
    LedgerReason.payout => 'Payout',
    LedgerReason.payoutReversal => 'Payout reversed',
    LedgerReason.adjustment => 'Adjustment',
    LedgerReason.unknown => 'Wallet update',
  };
}

/// How the driver gets paid out.
@JsonEnum()
enum PayoutMethodType {
  @JsonValue('UPI')
  upi,
  @JsonValue('BANK')
  bank,
  unknown;

  String get label => switch (this) {
    PayoutMethodType.upi => 'UPI',
    PayoutMethodType.bank => 'Bank account',
    PayoutMethodType.unknown => '—',
  };

  /// The wire value sent in the `methodType` field.
  String get wireValue => switch (this) {
    PayoutMethodType.upi => 'UPI',
    PayoutMethodType.bank => 'BANK',
    PayoutMethodType.unknown => 'UPI',
  };
}

/// Settlement state of a withdrawal request.
@JsonEnum()
enum PayoutStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('PROCESSING')
  processing,
  @JsonValue('PAID')
  paid,
  @JsonValue('REJECTED')
  rejected,
  unknown;

  String get label => switch (this) {
    PayoutStatus.pending => 'Pending',
    PayoutStatus.processing => 'Processing',
    PayoutStatus.paid => 'Paid',
    PayoutStatus.rejected => 'Rejected',
    PayoutStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    PayoutStatus.pending => StatusTone.warning,
    PayoutStatus.processing => StatusTone.info,
    PayoutStatus.paid => StatusTone.success,
    PayoutStatus.rejected => StatusTone.danger,
    PayoutStatus.unknown => StatusTone.neutral,
  };
}

/// One of the three earnings windows the dashboard shows.
enum EarningsPeriod {
  today,
  thisWeek,
  thisMonth;

  /// The path segment under `/drivers/me/earnings/`.
  String get path => switch (this) {
    EarningsPeriod.today => 'today',
    EarningsPeriod.thisWeek => 'this-week',
    EarningsPeriod.thisMonth => 'this-month',
  };

  String get label => switch (this) {
    EarningsPeriod.today => 'Today',
    EarningsPeriod.thisWeek => 'This week',
    EarningsPeriod.thisMonth => 'This month',
  };
}
