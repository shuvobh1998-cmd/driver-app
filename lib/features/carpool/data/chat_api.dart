import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/chat.dart';

/// Transport over the 1:1 chat endpoints (D6).
class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  /// Sends a message to [toUserId], optionally tied to a scheduled trip.
  Future<ChatMessage> send({
    required String toUserId,
    required String message,
    String? scheduledTripId,
  }) async {
    final res = await _dio.post<dynamic>(
      '/chats/messages',
      data: {
        'toUserId': toUserId,
        'message': message,
        'scheduledTripId': ?scheduledTripId,
      },
    );
    return res.unwrap(ChatMessage.fromJson);
  }

  /// All conversation threads, latest message first, with unread counts.
  Future<List<ChatThread>> threads({int page = 1, int pageSize = 30}) async {
    final res = await _dio.get<dynamic>(
      '/chats/threads',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return res.unwrapList(ChatThread.fromJson);
  }

  /// Messages with [otherUserId], newest first (paginated).
  Future<List<ChatMessage>> messages(
    String otherUserId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final res = await _dio.get<dynamic>(
      '/chats/threads/$otherUserId/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return res.unwrapList(ChatMessage.fromJson);
  }

  /// Marks every message from [otherUserId] as read.
  Future<void> markRead(String otherUserId) async {
    await _dio.post<dynamic>(
      '/chats/threads/$otherUserId/read',
      data: const <String, dynamic>{},
    );
  }
}
