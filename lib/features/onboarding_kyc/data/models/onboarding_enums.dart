import 'package:json_annotation/json_annotation.dart';

import '../../../../design_system/design_system.dart';

/// Overall KYC review state, shared by the driver profile and `kyc/status`.
/// [unknown] guards against a value the app doesn't yet know about.
@JsonEnum()
enum KycStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('IN_REVIEW')
  inReview,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('REJECTED')
  rejected,
  unknown;

  String get label => switch (this) {
    KycStatus.pending => 'Not submitted',
    KycStatus.inReview => 'In review',
    KycStatus.approved => 'Approved',
    KycStatus.rejected => 'Action needed',
    KycStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    KycStatus.pending => StatusTone.neutral,
    KycStatus.inReview => StatusTone.warning,
    KycStatus.approved => StatusTone.success,
    KycStatus.rejected => StatusTone.danger,
    KycStatus.unknown => StatusTone.neutral,
  };
}

/// KYC document types accepted by the backend. The driver app surfaces
/// AADHAAR + DL as required and RC / INSURANCE / PERMIT as optional.
@JsonEnum()
enum KycDocType {
  @JsonValue('AADHAAR')
  aadhaar,
  @JsonValue('DL')
  dl,
  @JsonValue('PAN')
  pan,
  @JsonValue('RC')
  rc,
  @JsonValue('INSURANCE')
  insurance,
  @JsonValue('PERMIT')
  permit,
  unknown;

  /// The wire value sent in the multipart `docType` field.
  String get wireValue => switch (this) {
    KycDocType.aadhaar => 'AADHAAR',
    KycDocType.dl => 'DL',
    KycDocType.pan => 'PAN',
    KycDocType.rc => 'RC',
    KycDocType.insurance => 'INSURANCE',
    KycDocType.permit => 'PERMIT',
    KycDocType.unknown => 'AADHAAR',
  };

  String get label => switch (this) {
    KycDocType.aadhaar => 'Aadhaar card',
    KycDocType.dl => 'Driving licence',
    KycDocType.pan => 'PAN card',
    KycDocType.rc => 'Registration certificate (RC)',
    KycDocType.insurance => 'Vehicle insurance',
    KycDocType.permit => 'Commercial permit',
    KycDocType.unknown => 'Document',
  };

  /// Whether a document number field is collected for this type.
  bool get collectsNumber =>
      this == KycDocType.aadhaar ||
      this == KycDocType.dl ||
      this == KycDocType.pan;
}

/// Vehicle category, matching the backend enum.
@JsonEnum()
enum VehicleType {
  @JsonValue('BIKE')
  bike,
  @JsonValue('AUTO')
  auto,
  @JsonValue('CNG')
  cng,
  @JsonValue('CAR')
  car,
  unknown;

  String get wireValue => switch (this) {
    VehicleType.bike => 'BIKE',
    VehicleType.auto => 'AUTO',
    VehicleType.cng => 'CNG',
    VehicleType.car => 'CAR',
    VehicleType.unknown => 'CAR',
  };

  String get label => switch (this) {
    VehicleType.bike => 'Bike',
    VehicleType.auto => 'Auto',
    VehicleType.cng => 'CNG',
    VehicleType.car => 'Car',
    VehicleType.unknown => 'Vehicle',
  };
}

/// Vehicle approval state.
@JsonEnum()
enum VehicleStatus {
  @JsonValue('PENDING_APPROVAL')
  pendingApproval,
  @JsonValue('ACTIVE')
  active,
  @JsonValue('INACTIVE')
  inactive,
  unknown;

  String get label => switch (this) {
    VehicleStatus.pendingApproval => 'Pending approval',
    VehicleStatus.active => 'Approved',
    VehicleStatus.inactive => 'Inactive',
    VehicleStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    VehicleStatus.pendingApproval => StatusTone.warning,
    VehicleStatus.active => StatusTone.success,
    VehicleStatus.inactive => StatusTone.neutral,
    VehicleStatus.unknown => StatusTone.neutral,
  };
}
