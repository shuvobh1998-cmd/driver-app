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
  'UNAUTHENTICATED': 'Please sign in to continue.',
  'UNAUTHORIZED': 'Please sign in to continue.',
  'FORBIDDEN': "You don't have permission to do that.",
  'NOT_FOUND': 'We could not find what you were looking for.',
  'DUPLICATE': 'That already exists.',
  'INVALID_STATE': "That action isn't allowed right now.",
  'VALIDATION_ERROR': 'Please check the details and try again.',
  'RATE_LIMITED': 'Too many attempts. Please wait a moment and retry.',
  'INTERNAL_ERROR': 'Something went wrong on our end. Please try again.',
  'SERVICE_UNAVAILABLE':
      'Service is temporarily unavailable. Try again shortly.',
  // Auth (D1):
  'INVALID_CREDENTIALS': 'Incorrect phone or password.',
  'USER_NOT_FOUND': 'No account found for this phone number.',
  'PHONE_ALREADY_REGISTERED':
      'This number is already registered. Please log in instead.',
  'PHONE_ALREADY_EXISTS':
      'This number is already registered. Please log in instead.',
  'PHONE_NOT_REGISTERED': 'This phone number is not registered yet.',
  'OTP_EXPIRED': 'That code has expired. Request a new one.',
  'SIGNUP_TOKEN_INVALID': 'Your signup session expired. Please start again.',
  'SIGNUP_TICKET_INVALID': 'Your signup session expired. Please start again.',
  'RESET_TICKET_INVALID': 'Your reset session expired. Please start again.',
  'FIREBASE_TOKEN_INVALID': 'Phone verification failed. Please try again.',
  'OTP_COOLDOWN': 'Please wait before requesting another code.',
  'PASSWORD_MISMATCH': 'The passwords do not match.',
  'WEAK_PASSWORD': 'Use a 6-digit numeric password.',
  'CURRENT_PASSWORD_INVALID': 'Your current password is incorrect.',
  'ACCOUNT_SUSPENDED': 'This account is suspended. Contact support.',
  'ACCOUNT_BANNED': 'This account has been banned. Contact support.',
  'PHONE_VERIFICATION_UNAVAILABLE':
      'Phone verification is not set up on this build yet.',
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

/// Resolves the best message to show for a backend failure: a locally-mapped
/// message for the [code] if we have one, otherwise the backend's own
/// [serverMessage] (usually meaningful), otherwise the generic fallback. This
/// means an unmapped code never hides a useful server explanation.
String resolveErrorMessage(String code, [String? serverMessage]) {
  final mapped = kErrorMessages[code];
  if (mapped != null) return mapped;
  final server = serverMessage?.trim();
  if (server != null && server.isNotEmpty) return server;
  return kErrorMessages['UNKNOWN']!;
}
