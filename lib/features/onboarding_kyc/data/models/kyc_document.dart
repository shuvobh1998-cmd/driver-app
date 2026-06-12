import 'package:json_annotation/json_annotation.dart';

import 'onboarding_enums.dart';

part 'kyc_document.g.dart';

/// A single uploaded KYC document, from `GET/POST /drivers/me/kyc/documents`.
@JsonSerializable()
class KycDocument {
  const KycDocument({
    required this.id,
    required this.docType,
    required this.fileUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.verified,
    this.docNumber,
    this.expiresAt,
    this.uploadedAt,
  });

  final String id;
  @JsonKey(unknownEnumValue: KycDocType.unknown)
  final KycDocType docType;
  final String? docNumber;
  final String fileUrl;
  final String mimeType;
  final int sizeBytes;
  final bool verified;

  /// ISO-8601 date string (`YYYY-MM-DD`); kept as-is for display.
  final String? expiresAt;
  final DateTime? uploadedAt;

  bool get isPdf => mimeType == 'application/pdf';

  factory KycDocument.fromJson(Map<String, dynamic> json) =>
      _$KycDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$KycDocumentToJson(this);
}
