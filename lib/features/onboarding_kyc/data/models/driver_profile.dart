import 'package:json_annotation/json_annotation.dart';

import 'onboarding_enums.dart';

part 'driver_profile.g.dart';

/// The driver profile returned by `POST/GET/PATCH /drivers/me/profile`. Carries
/// the overall KYC status and the emergency contact captured during onboarding.
@JsonSerializable()
class DriverProfile {
  const DriverProfile({
    required this.publicId,
    required this.phone,
    required this.kycStatus,
    required this.totalTrips,
    required this.ratingAvg,
    required this.ratingCount,
    this.firstName,
    this.lastName,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.kycRejectedReason,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String publicId;
  final String phone;
  final String? firstName;
  final String? lastName;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  @JsonKey(unknownEnumValue: KycStatus.unknown)
  final KycStatus kycStatus;
  final String? kycRejectedReason;
  final DateTime? approvedAt;
  final int totalTrips;
  final num ratingAvg;
  final int ratingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DriverProfile.fromJson(Map<String, dynamic> json) =>
      _$DriverProfileFromJson(json);

  Map<String, dynamic> toJson() => _$DriverProfileToJson(this);
}
