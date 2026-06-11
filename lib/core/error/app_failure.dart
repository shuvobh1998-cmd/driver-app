/// A normalized failure carrying the backend `error.code`. UI branches on
/// [code] (never on message text), per the handoff conventions.
class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.serverMessage,
  });

  /// Machine-readable code, e.g. `KYC_INCOMPLETE`, `OTP_INVALID`,
  /// `TOKEN_EXPIRED`, `INSUFFICIENT_BALANCE`. The single thing UI switches on.
  final String code;

  /// User-facing message resolved from [code] via the error map.
  final String message;

  /// HTTP status, when the failure originated from a response.
  final int? statusCode;

  /// The raw `error.message` from the backend, kept for diagnostics and as the
  /// fallback shown when [code] has no entry in the local message map.
  final String? serverMessage;

  /// Sentinel for failures we could not attribute to a known code.
  static const String unknownCode = 'UNKNOWN';

  @override
  String toString() =>
      'AppFailure($code, status=$statusCode, server=$serverMessage)';
}
