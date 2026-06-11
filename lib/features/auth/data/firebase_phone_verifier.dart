import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/error/error_messages.dart';
import 'phone_verifier.dart';

/// [PhoneVerifier] backed by `firebase_auth`. Drives Firebase phone sign-in
/// (which sends the SMS / honours test numbers) and returns the Firebase ID
/// token the backend verifies.
///
/// Flow: [sendCode] kicks off `verifyPhoneNumber` and resolves once Firebase
/// reports the code was sent; [confirmCode] exchanges the user-entered SMS code
/// for a credential, signs in, and returns `getIdToken()`.
class FirebasePhoneVerifier implements PhoneVerifier {
  FirebasePhoneVerifier([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  String? _verificationId;
  PhoneAuthCredential? _autoCredential;

  @override
  Future<void> sendCode(String e164Phone) async {
    _verificationId = null;
    _autoCredential = null;
    final completer = Completer<void>();

    await _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        // Android auto-retrieval: keep the credential for confirmCode().
        _autoCredential = credential;
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(_map(e));
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  @override
  Future<String> confirmCode(String smsCode) async {
    final credential =
        _autoCredential ??
        (_verificationId == null
            ? throw const AppFailure(
                code: 'OTP_REQUIRED',
                message: 'Request a code before verifying.',
              )
            : PhoneAuthProvider.credential(
                verificationId: _verificationId!,
                smsCode: smsCode,
              ));

    try {
      final result = await _auth.signInWithCredential(credential);
      final token = await result.user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw _failure('FIREBASE_TOKEN_INVALID');
      }
      return token;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  AppFailure _map(FirebaseAuthException e) {
    final code = switch (e.code) {
      'invalid-verification-code' => 'OTP_INVALID',
      'session-expired' => 'OTP_INVALID',
      'invalid-phone-number' => 'VALIDATION_ERROR',
      'too-many-requests' => 'RATE_LIMITED',
      'missing-verification-code' => 'OTP_REQUIRED',
      _ => 'FIREBASE_TOKEN_INVALID',
    };
    return _failure(code);
  }

  AppFailure _failure(String code) =>
      AppFailure(code: code, message: errorMessageFor(code));
}
