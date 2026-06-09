import 'package:intl/intl.dart';

/// The one place money is formatted. Backend money is always integer **paise**;
/// this converts to a ₹ string with Indian digit grouping. Never format paise
/// ad-hoc elsewhere — always route through here.
///
/// ```dart
/// formatPaise(123450); // "₹1,234.50"
/// formatPaise(50000, showDecimals: false); // "₹500"
/// ```
String formatPaise(int paise, {bool showDecimals = true}) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: showDecimals ? 2 : 0,
  );
  return formatter.format(paise / 100);
}
