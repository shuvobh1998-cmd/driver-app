import 'package:json_annotation/json_annotation.dart';

part 'wallet.g.dart';

/// The driver's wallet snapshot (`GET /drivers/me/wallet`). All money is integer
/// **paise**; render with `formatPaise`.
@JsonSerializable(createToJson: false)
class Wallet {
  const Wallet({
    required this.balance,
    required this.totalEarned,
    required this.totalPaidOut,
    required this.currency,
  });

  /// Withdrawable balance, in paise.
  final int balance;

  /// Lifetime gross credited to the wallet, in paise.
  final int totalEarned;

  /// Lifetime amount paid out, in paise.
  final int totalPaidOut;

  final String currency;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}
