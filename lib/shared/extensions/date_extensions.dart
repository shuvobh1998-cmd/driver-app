import 'package:intl/intl.dart';

/// Date helpers. The backend speaks ISO-8601 UTC; the UI shows IST. Parse
/// to UTC, render in local time.
extension DateTimeFormatting on DateTime {
  /// ISO-8601 in UTC, the wire format for all timestamps we send.
  String toIso8601Utc() => toUtc().toIso8601String();

  /// e.g. "9 Jun 2026, 4:30 PM" in the device locale.
  String toFriendly() => DateFormat.yMMMd().add_jm().format(toLocal());

  /// e.g. "4:30 PM".
  String toTimeOfDay() => DateFormat.jm().format(toLocal());
}

/// Parses an ISO-8601 string from the API, treating it as UTC.
DateTime? parseIsoUtc(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
