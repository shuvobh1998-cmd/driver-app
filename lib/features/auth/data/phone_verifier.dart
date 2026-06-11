import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/error/error_messages.dart';

/// Client-side phone verification. Per the backend handoff, the OTP SMS is sent
/// by **Firebase** (`firebase_auth`), not our backend — the app proves the
/// phone to Firebase and forwards the resulting Firebase ID token to
/// `/auth/signup/verify-otp` / `/auth/otp/verify` / `/auth/password/forgot/reset`.
///
/// This interface isolates that step so the rest of auth is testable and so a
/// Firebase implementation can be dropped in once a Firebase project (and
/// `google-services.json`) is configured for the driver app.
abstract class PhoneVerifier {
  /// Asks the provider to SMS a code to [e164Phone]. Completes when the code
  /// has been dispatched (or when auto-retrieval is pending).
  Future<void> sendCode(String e164Phone);

  /// Confirms the user-entered [smsCode] and returns a **Firebase ID token**
  /// to hand to the backend.
  Future<String> confirmCode(String smsCode);
}

/// Default verifier for builds without a Firebase project wired in. Every call
/// fails cleanly with [PHONE_VERIFICATION_UNAVAILABLE] so the OTP screens show
/// an honest message instead of silently breaking.
class UnconfiguredPhoneVerifier implements PhoneVerifier {
  const UnconfiguredPhoneVerifier();

  static const _code = 'PHONE_VERIFICATION_UNAVAILABLE';

  AppFailure get _failure =>
      AppFailure(code: _code, message: errorMessageFor(_code));

  @override
  Future<void> sendCode(String e164Phone) => throw _failure;

  @override
  Future<String> confirmCode(String smsCode) => throw _failure;
}

/// The active phone verifier. Override this in the bootstrap once
/// `firebase_auth` is configured to enable OTP signup / reset.
final phoneVerifierProvider = Provider<PhoneVerifier>(
  (ref) => const UnconfiguredPhoneVerifier(),
);
