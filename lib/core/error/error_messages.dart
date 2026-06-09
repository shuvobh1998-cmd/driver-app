/// The single `error.code → user message` map. Every screen renders failures
/// through [errorMessageFor]; we never surface raw exception text.
///
/// Codes are filled in per feature sprint (auth in D1, KYC in D2, …); this
/// skeleton seeds the cross-cutting ones and a safe fallback.
const Map<String, String> kErrorMessages = {
  'UNKNOWN': 'Something went wrong. Please try again.',
  'NETWORK': 'No internet connection. Check your network and retry.',
  'TIMEOUT': 'The request took too long. Please try again.',
  'TOKEN_EXPIRED': 'Your session expired. Please sign in again.',
  'UNAUTHORIZED': 'Please sign in to continue.',
  // Seeded for later sprints so the keys are discoverable:
  'OTP_INVALID': 'That code is incorrect. Please try again.',
  'OTP_REQUIRED': 'Enter the verification code to continue.',
  'KYC_INCOMPLETE': 'Finish your documents before going online.',
  'KYC_REJECTED': 'A document was rejected. Tap to see why and re-upload.',
  'VEHICLE_NOT_APPROVED': 'Your vehicle is awaiting approval.',
  'INSUFFICIENT_BALANCE': 'Your wallet balance is too low for this payout.',
  'PAYOUT_METHOD_REQUIRED': 'Add a payout method before withdrawing.',
  'ALREADY_RATED': 'You have already rated this trip.',
};

/// Resolves a user-facing message for an `error.code`, falling back to the
/// generic message when the code is unmapped.
String errorMessageFor(String code) =>
    kErrorMessages[code] ?? kErrorMessages['UNKNOWN']!;
