import 'package:json_annotation/json_annotation.dart';

part 'auth_session.g.dart';

/// A device session as listed by `GET /users/me/sessions`. `current` marks the
/// device this app is running on (it can't be revoked from the list).
@JsonSerializable()
class AuthSession {
  const AuthSession({
    required this.id,
    required this.current,
    this.device,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String? device;
  final bool current;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  String get deviceLabel =>
      (device == null || device!.isEmpty) ? 'Unknown device' : device!;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);

  Map<String, dynamic> toJson() => _$AuthSessionToJson(this);
}
