import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/models/user_profile.dart';
import 'models/account_deletion.dart';
import 'models/user_preferences.dart';

/// Transport over the authenticated `/users/me/*` endpoints (profile, avatar,
/// preferences, sessions, account deletion).
class UserApi {
  UserApi(this._dio);

  final Dio _dio;

  Future<UserProfile> getProfile() async {
    final res = await _dio.get<dynamic>('/users/me/profile');
    return res.unwrap(UserProfile.fromJson);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> patch) async {
    final res = await _dio.patch<dynamic>('/users/me/profile', data: patch);
    return res.unwrap(UserProfile.fromJson);
  }

  /// Uploads an avatar as multipart (`avatar` field) and returns the new URL.
  Future<String> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final res = await _dio.post<dynamic>('/users/me/avatar', data: form);
    return res.unwrap((j) => j['avatarUrl'] as String);
  }

  Future<UserPreferences> getPreferences() async {
    final res = await _dio.get<dynamic>('/users/me/preferences');
    return res.unwrap(UserPreferences.fromJson);
  }

  Future<UserPreferences> updatePreferences(Map<String, dynamic> patch) async {
    final res = await _dio.patch<dynamic>('/users/me/preferences', data: patch);
    return res.unwrap(UserPreferences.fromJson);
  }

  Future<List<AuthSession>> getSessions() async {
    final res = await _dio.get<dynamic>('/users/me/sessions');
    return res.unwrapList(AuthSession.fromJson);
  }

  Future<void> revokeSession(String id) =>
      _dio.delete<dynamic>('/users/me/sessions/$id');

  Future<AccountDeletion> requestAccountDeletion() async {
    final res = await _dio.post<dynamic>('/users/me/account/delete-request');
    return res.unwrap(AccountDeletion.fromJson);
  }

  Future<AccountDeletion> cancelAccountDeletion() async {
    final res = await _dio.post<dynamic>(
      '/users/me/account/delete-request/cancel',
    );
    return res.unwrap(AccountDeletion.fromJson);
  }
}
