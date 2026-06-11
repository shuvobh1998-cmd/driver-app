import 'package:json_annotation/json_annotation.dart';

import 'auth_user.dart';

part 'auth_response.g.dart';

/// The auth payload returned by login / signup-complete / otp-verify / refresh.
@JsonSerializable()
class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;

  /// Access-token TTL in seconds.
  final int expiresIn;
  final AuthUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}
