import 'package:json_annotation/json_annotation.dart';

import 'carpool_enums.dart';

part 'chat.g.dart';

/// A single 1:1 chat message (`POST /chats/messages`,
/// `GET /chats/threads/:otherUserId/messages`). [mine] is true when the signed-in
/// driver authored it, so the UI can align the bubble without comparing ids.
@JsonSerializable(createToJson: false)
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.type,
    required this.body,
    required this.mine,
    required this.createdAt,
    this.scheduledTripId,
    this.readAt,
  });

  final String id;
  final String? scheduledTripId;
  final String fromUserId;
  final String toUserId;

  @JsonKey(unknownEnumValue: ChatMessageType.unknown)
  final ChatMessageType type;

  final String body;
  final bool mine;
  final DateTime? readAt;
  final DateTime createdAt;

  /// The other party in this message, relative to the signed-in driver.
  String get otherUserId => mine ? toUserId : fromUserId;

  bool get isSystem => type == ChatMessageType.system;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// Lenient parse for a `chat.message.received` socket payload, which may not
  /// carry the full envelope shape — returns null when it can't be read.
  static ChatMessage? tryParse(dynamic data) {
    if (data is! Map) return null;
    try {
      return ChatMessage.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }
}

/// A conversation summary (`GET /chats/threads`): the other user plus the latest
/// message preview and this driver's unread count.
@JsonSerializable(createToJson: false)
class ChatThread {
  const ChatThread({
    required this.otherUserId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unread,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  final String otherUserId;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unread;

  /// Display name for the other party, falling back to "Rider".
  String get name {
    final full = [
      if (firstName != null && firstName!.isNotEmpty) firstName,
      if (lastName != null && lastName!.isNotEmpty) lastName,
    ].join(' ');
    return full.isEmpty ? 'Rider' : full;
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) =>
      _$ChatThreadFromJson(json);
}
