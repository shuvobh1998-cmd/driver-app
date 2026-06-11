import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/auth_response.dart';
import 'models/auth_user.dart';
import 'models/device_info.dart';

/// Thin transport over the `/auth/*` and `/auth/me` endpoints. Returns typed
/// models (envelope already unwrapped); error normalization is handled by the
/// shared interceptor stack, so callers just `try/catch` an [AppFailure].
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  // ── Login ──────────────────────────────────────────────────────────────
  Future<AuthResponse> login({
    required String phone,
    required String password,
    DeviceInfo? deviceInfo,
  }) async {
    final res = await _dio.post<dynamic>(
      '/auth/login',
      data: {
        'phone': phone,
        'password': password,
        if (deviceInfo != null) 'deviceInfo': deviceInfo.toJson(),
      },
    );
    return res.unwrap(AuthResponse.fromJson);
  }

  // ── Signup (3 steps + Firebase OTP in between) ──────────────────────────
  /// Returns `(signupTicket, cooldownSeconds)`.
  Future<({String ticket, int cooldownSeconds})> signupStart(
    String phone,
  ) async {
    final res = await _dio.post<dynamic>(
      '/auth/signup/start',
      data: {'phone': phone},
    );
    return res.unwrap(
      (j) => (
        ticket: j['signupTicket'] as String,
        cooldownSeconds: (j['cooldownSeconds'] as num?)?.toInt() ?? 60,
      ),
    );
  }

  /// Exchanges the Firebase ID token for a short-lived signup token.
  Future<String> signupVerifyOtp({
    required String signupTicket,
    required String firebaseIdToken,
    DeviceInfo? deviceInfo,
  }) async {
    final res = await _dio.post<dynamic>(
      '/auth/signup/verify-otp',
      data: {
        'signupTicket': signupTicket,
        'firebaseIdToken': firebaseIdToken,
        if (deviceInfo != null) 'deviceInfo': deviceInfo.toJson(),
      },
    );
    return res.unwrap((j) => j['signupToken'] as String);
  }

  Future<AuthResponse> signupComplete({
    required String signupToken,
    required String firstName,
    required String password,
    required String passwordConfirm,
    String? lastName,
    String? email,
    String? gender,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DeviceInfo? deviceInfo,
  }) async {
    final res = await _dio.post<dynamic>(
      '/auth/signup/complete',
      data: {
        'signupToken': signupToken,
        'firstName': firstName,
        'password': password,
        'passwordConfirm': passwordConfirm,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
        if (email != null && email.isNotEmpty) 'email': email,
        'gender': ?gender,
        if (emergencyContactName != null && emergencyContactName.isNotEmpty)
          'emergencyContactName': emergencyContactName,
        if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty)
          'emergencyContactPhone': emergencyContactPhone,
        if (deviceInfo != null) 'deviceInfo': deviceInfo.toJson(),
      },
    );
    return res.unwrap(AuthResponse.fromJson);
  }

  // ── Passwordless login via OTP (existing user) ──────────────────────────
  Future<int> otpSend(String phone) async {
    final res = await _dio.post<dynamic>(
      '/auth/otp/send',
      data: {'phone': phone},
    );
    return res.unwrap((j) => (j['cooldownSeconds'] as num?)?.toInt() ?? 60);
  }

  Future<AuthResponse> otpVerify({
    required String firebaseIdToken,
    DeviceInfo? deviceInfo,
  }) async {
    final res = await _dio.post<dynamic>(
      '/auth/otp/verify',
      data: {
        'idToken': firebaseIdToken,
        if (deviceInfo != null) 'deviceInfo': deviceInfo.toJson(),
      },
    );
    return res.unwrap(AuthResponse.fromJson);
  }

  // ── Forgot / change password ────────────────────────────────────────────
  Future<String> forgotRequest(String phone) async {
    final res = await _dio.post<dynamic>(
      '/auth/password/forgot/request',
      data: {'phone': phone},
    );
    return res.unwrap((j) => j['resetTicket'] as String);
  }

  Future<AuthResponse> forgotReset({
    required String resetTicket,
    required String firebaseIdToken,
    required String newPassword,
    required String newPasswordConfirm,
    DeviceInfo? deviceInfo,
  }) async {
    final res = await _dio.post<dynamic>(
      '/auth/password/forgot/reset',
      data: {
        'resetTicket': resetTicket,
        'firebaseIdToken': firebaseIdToken,
        'newPassword': newPassword,
        'newPasswordConfirm': newPasswordConfirm,
        if (deviceInfo != null) 'deviceInfo': deviceInfo.toJson(),
      },
    );
    return res.unwrap(AuthResponse.fromJson);
  }

  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final res = await _dio.post<dynamic>(
      '/auth/password/change',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'newPasswordConfirm': newPasswordConfirm,
      },
    );
    return res.unwrap(AuthResponse.fromJson);
  }

  // ── Session ──────────────────────────────────────────────────────────────
  Future<AuthUser> me() async {
    final res = await _dio.get<dynamic>('/auth/me');
    return res.unwrap(AuthUser.fromJson);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<dynamic>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }

  Future<int> logoutAllOthers(String refreshToken) async {
    final res = await _dio.post<dynamic>(
      '/auth/logout/all-others',
      data: {'refreshToken': refreshToken},
    );
    return res.unwrap((j) => (j['revoked'] as num?)?.toInt() ?? 0);
  }
}
