import 'package:json_annotation/json_annotation.dart';

part 'earnings_summary.g.dart';

/// Earnings for one window (`GET /drivers/me/earnings/{today|this-week|this-month}`).
/// [grossFare] and [netEarning] are integer **paise**; [from]/[to] bound the
/// window (IST day/week/month boundaries, expressed in UTC).
@JsonSerializable(createToJson: false)
class EarningsSummary {
  const EarningsSummary({
    required this.period,
    required this.from,
    required this.to,
    required this.tripsCount,
    required this.grossFare,
    required this.netEarning,
    required this.currency,
  });

  final String period;
  final DateTime from;
  final DateTime to;

  /// Number of completed trips in the window.
  final int tripsCount;

  /// Total fare collected (before commission/GST), in paise.
  final int grossFare;

  /// What the driver actually keeps, in paise.
  final int netEarning;

  final String currency;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      _$EarningsSummaryFromJson(json);
}
