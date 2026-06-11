import '../../../core/network/auth_token_service.dart';
import 'auth_api.dart';
import 'models/auth_response.dart';
import 'models/auth_user.dart';
import 'models/device_info.dart';

/// Coordinates the auth API with token persistence. Every call that yields an
/// [AuthResponse] also writes the rotated tokens into [AuthTokenService] before
/// returning the user, so the rest of the app only deals in [AuthUser].
class AuthRepository {
  AuthRepository({required this.api, required this.tokens});

  final AuthApi api;
  final AuthTokenService tokens;

  Future<AuthUser> _persist(AuthResponse res) async {
    await tokens.setTokens(
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
    return res.user;
  }

  Future<AuthUser> login({required String phone, required String password}) =>
      api
          .login(
            phone: phone,
            password: password,
            deviceInfo: DeviceInfo.current(),
          )
          .then(_persist);

  // Signup
  Future<({String ticket, int cooldownSeconds})> signupStart(String phone) =>
      api.signupStart(phone);

  Future<String> signupVerifyOtp({
    required String signupTicket,
    required String firebaseIdToken,
  }) => api.signupVerifyOtp(
    signupTicket: signupTicket,
    firebaseIdToken: firebaseIdToken,
    deviceInfo: DeviceInfo.current(),
  );

  Future<AuthUser> signupComplete({
    required String signupToken,
    required String firstName,
    required String password,
    required String passwordConfirm,
    String? lastName,
    String? email,
    String? gender,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) => api
      .signupComplete(
        signupToken: signupToken,
        firstName: firstName,
        password: password,
        passwordConfirm: passwordConfirm,
        lastName: lastName,
        email: email,
        gender: gender,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        deviceInfo: DeviceInfo.current(),
      )
      .then(_persist);

  // OTP login (existing user)
  Future<int> otpSend(String phone) => api.otpSend(phone);

  Future<AuthUser> otpVerify(String firebaseIdToken) => api
      .otpVerify(
        firebaseIdToken: firebaseIdToken,
        deviceInfo: DeviceInfo.current(),
      )
      .then(_persist);

  // Forgot / change password
  Future<String> forgotRequest(String phone) => api.forgotRequest(phone);

  Future<AuthUser> forgotReset({
    required String resetTicket,
    required String firebaseIdToken,
    required String newPassword,
    required String newPasswordConfirm,
  }) => api
      .forgotReset(
        resetTicket: resetTicket,
        firebaseIdToken: firebaseIdToken,
        newPassword: newPassword,
        newPasswordConfirm: newPasswordConfirm,
        deviceInfo: DeviceInfo.current(),
      )
      .then(_persist);

  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) => api
      .changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirm: newPasswordConfirm,
      )
      .then(_persist);

  /// Restores a session on launch: if a refresh token exists, mint a fresh
  /// access token then load the user. Returns null when there's no live
  /// session (no stored token, or refresh rejected).
  Future<AuthUser?> restoreSession() async {
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final ok = await tokens.refresh();
    if (!ok) {
      await tokens.clear();
      return null;
    }
    return api.me();
  }

  Future<AuthUser> me() => api.me();

  /// Logs out this device and clears local tokens. Best-effort network call —
  /// local state is cleared regardless.
  Future<void> logout() async {
    final refreshToken = await tokens.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await api.logout(refreshToken);
      }
    } finally {
      await tokens.clear();
    }
  }

  /// Revokes every other device, keeping this one. Returns the count revoked.
  Future<int> logoutAllOthers() async {
    final refreshToken = await tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return 0;
    return api.logoutAllOthers(refreshToken);
  }
}
