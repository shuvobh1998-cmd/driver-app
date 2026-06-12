import 'package:json_annotation/json_annotation.dart';

import 'onboarding_enums.dart';

part 'vehicle.g.dart';

/// A registered vehicle, from `GET/POST /drivers/me/vehicles`.
@JsonSerializable()
class Vehicle {
  const Vehicle({
    required this.publicId,
    required this.vehicleType,
    required this.registrationNumber,
    required this.seatCount,
    required this.status,
    this.make,
    this.model,
    this.year,
    this.color,
    this.photoUrl,
    this.rejectedReason,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String publicId;
  @JsonKey(unknownEnumValue: VehicleType.unknown)
  final VehicleType vehicleType;
  final String registrationNumber;
  final int seatCount;
  final String? make;
  final String? model;
  final int? year;
  final String? color;
  final String? photoUrl;
  @JsonKey(unknownEnumValue: VehicleStatus.unknown)
  final VehicleStatus status;
  final String? rejectedReason;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// A short human label, e.g. "Maruti Suzuki Swift" or just the type.
  String get title {
    final parts = [make, model].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? vehicleType.label : parts.join(' ');
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) =>
      _$VehicleFromJson(json);

  Map<String, dynamic> toJson() => _$VehicleToJson(this);
}
