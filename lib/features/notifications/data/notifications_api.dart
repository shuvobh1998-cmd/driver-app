import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/app_notification.dart';

/// Transport over the in-app notification inbox + FCM device-token endpoints (D7).
class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  /// One page of the inbox, newest first.
  Future<List<AppNotification>> inbox({int page = 1, int pageSize = 20}) async {
    final res = await _dio.get<dynamic>(
      '/notifications',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return res.unwrapList(AppNotification.fromJson);
  }

  /// Unread count for the tab/bell badge.
  Future<int> unreadCount() async {
    final res = await _dio.get<dynamic>('/notifications/unread-count');
    final data = res.data;
    final body = data is Map ? data['data'] : data;
    if (body is int) return body;
    if (body is Map) {
      final c = body['count'] ?? body['unread'] ?? body['unreadCount'];
      if (c is int) return c;
      if (c is num) return c.toInt();
    }
    if (body is num) return body.toInt();
    return 0;
  }

  /// Marks one notification read; returns the updated row.
  Future<AppNotification> markRead(String id) async {
    final res = await _dio.post<dynamic>(
      '/notifications/$id/read',
      data: const <String, dynamic>{},
    );
    return res.unwrap(AppNotification.fromJson);
  }

  /// Marks every notification read.
  Future<void> markAllRead() async {
    await _dio.post<dynamic>(
      '/notifications/read-all',
      data: const <String, dynamic>{},
    );
  }

  /// Registers / refreshes this device's FCM token.
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  }) async {
    await _dio.post<dynamic>(
      '/users/me/device-tokens',
      data: {
        'fcmToken': fcmToken,
        'platform': platform,
        'deviceInfo': ?deviceInfo,
      },
    );
  }

  /// Unregisters an FCM token (on sign-out).
  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _dio.delete<dynamic>(
      '/users/me/device-tokens',
      data: {'fcmToken': fcmToken},
    );
  }
}
