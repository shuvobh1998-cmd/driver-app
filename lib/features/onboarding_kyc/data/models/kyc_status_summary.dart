import 'package:json_annotation/json_annotation.dart';

import 'onboarding_enums.dart';

part 'kyc_status_summary.g.dart';

/// The `GET /drivers/me/kyc/status` summary: the overall review [status] plus
/// which doc types are [uploaded], [required] and still [missing].
@JsonSerializable()
class KycStatusSummary {
  const KycStatusSummary({
    required this.status,
    required this.uploaded,
    required this.requiredDocs,
    required this.missing,
    this.rejectedReason,
    this.approvedAt,
  });

  @JsonKey(unknownEnumValue: KycStatus.unknown)
  final KycStatus status;
  @JsonKey(defaultValue: <KycDocType>[])
  final List<KycDocType> uploaded;
  @JsonKey(name: 'required', defaultValue: <KycDocType>[])
  final List<KycDocType> requiredDocs;
  @JsonKey(defaultValue: <KycDocType>[])
  final List<KycDocType> missing;
  final String? rejectedReason;
  final DateTime? approvedAt;

  /// True once every required document has been uploaded.
  bool get allRequiredUploaded => missing.isEmpty;

  factory KycStatusSummary.fromJson(Map<String, dynamic> json) =>
      _$KycStatusSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$KycStatusSummaryToJson(this);
}
