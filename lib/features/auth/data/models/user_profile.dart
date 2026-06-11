import 'package:json_annotation/json_annotation.dart';

import 'gender.dart';

part 'user_profile.g.dart';

/// The full profile returned by `GET/PATCH /users/me/profile`. Richer than
/// [AuthUser]: adds emergency contact, verification flags and timestamps.
@JsonSerializable()
class UserProfile {
  const UserProfile({
    required this.publicId,
    required this.phone,
    required this.roles,
    required this.status,
    required this.passwordSet,
    required this.emailVerified,
    this.email,
    this.firstName,
    this.lastName,
    this.dob,
    this.gender,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String publicId;
  final String phone;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? dob;
  @JsonKey(unknownEnumValue: Gender.unknown)
  final Gender? gender;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? avatarUrl;
  final bool passwordSet;
  final bool emailVerified;
  final List<String> roles;
  @JsonKey(unknownEnumValue: AccountStatus.unknown)
  final AccountStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final name = [firstName, lastName].whereType<String>().join(' ').trim();
    return name.isEmpty ? phone : name;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
