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
  'NOT_FOUND': 'We could not find what you were looking for.',
  'VALIDATION_ERROR': 'Please check the details and try again.',
  'RATE_LIMITED': 'Too many attempts. Please wait a moment and retry.',
  // Auth (D1):
  'INVALID_CREDENTIALS': 'Incorrect phone or password.',
  'USER_NOT_FOUND': 'No account found for this phone number.',
  'PHONE_ALREADY_EXISTS': 'An account already exists for this phone number.',
  'PHONE_NOT_REGISTERED': 'This phone number is not registered yet.',
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
