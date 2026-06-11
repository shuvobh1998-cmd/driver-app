/// India-first phone helpers. The UI collects a bare 10-digit mobile number;
/// the backend wants E.164 (`+91XXXXXXXXXX`).
abstract final class Phone {
  static const dialCode = '+91';

  /// Wraps a 10-digit national number into E.164. If it already looks like a
  /// `+`-prefixed international number, it's returned unchanged.
  static String toE164(String national) {
    final v = national.trim();
    if (v.startsWith('+')) return v;
    return '$dialCode$v';
  }

  /// Pretty national form for display, e.g. `+919876543210` → `+91 98765 43210`.
  static String pretty(String e164) {
    final v = e164.trim();
    if (v.startsWith(dialCode) && v.length == 13) {
      final n = v.substring(3);
      return '$dialCode ${n.substring(0, 5)} ${n.substring(5)}';
    }
    return v;
  }
}
