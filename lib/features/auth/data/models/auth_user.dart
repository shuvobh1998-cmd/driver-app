import 'package:json_annotation/json_annotation.dart';

import 'gender.dart';

part 'auth_user.g.dart';

/// The signed-in user as returned inside the auth payload and by `GET /auth/me`.
@JsonSerializable()
class AuthUser {
  const AuthUser({
    required this.publicId,
    required this.phone,
    required this.roles,
    required this.status,
    this.email,
    this.firstName,
    this.lastName,
    this.dob,
    this.gender,
    this.avatarUrl,
    this.createdAt,
  });

  final String publicId;
  final String phone;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? dob;
  @JsonKey(unknownEnumValue: Gender.unknown)
  final Gender? gender;
  final String? avatarUrl;
  final List<String> roles;
  @JsonKey(unknownEnumValue: AccountStatus.unknown)
  final AccountStatus status;
  final DateTime? createdAt;

  bool get isDriver => roles.contains('DRIVER');

  String get displayName {
    final name = [firstName, lastName].whereType<String>().join(' ').trim();
    return name.isEmpty ? phone : name;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);

  Map<String, dynamic> toJson() => _$AuthUserToJson(this);
}
