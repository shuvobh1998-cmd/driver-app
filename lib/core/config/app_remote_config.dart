import 'package:json_annotation/json_annotation.dart';

part 'app_remote_config.g.dart';

/// Per-platform app versions advertised by `GET /app/config`.
@JsonSerializable()
class AppVersion {
  const AppVersion({this.android, this.ios});

  final String? android;
  final String? ios;

  factory AppVersion.fromJson(Map<String, dynamic> json) =>
      _$AppVersionFromJson(json);
  Map<String, dynamic> toJson() => _$AppVersionToJson(this);
}

/// A selectable vehicle type from the platform config (used from D2 onward).
@JsonSerializable()
class VehicleTypeOption {
  const VehicleTypeOption({
    required this.code,
    required this.label,
    this.iconUrl,
  });

  final String code;
  final String label;
  final String? iconUrl;

  factory VehicleTypeOption.fromJson(Map<String, dynamic> json) =>
      _$VehicleTypeOptionFromJson(json);
  Map<String, dynamic> toJson() => _$VehicleTypeOptionToJson(this);
}

/// Remote runtime config from `GET /app/config`. Drives the force-update gate
/// on splash plus support contacts and legal links surfaced in settings.
@JsonSerializable()
class AppRemoteConfig {
  const AppRemoteConfig({
    required this.vehicleTypes,
    required this.supportPhone,
    required this.supportEmail,
    required this.supportHours,
    required this.termsUrl,
    required this.privacyUrl,
    required this.driverAgreementUrl,
    required this.city,
    required this.currency,
    required this.languages,
    required this.minSupportedVersion,
    required this.latestVersion,
    required this.forceUpdate,
    this.razorpayKeyId,
  });

  final List<VehicleTypeOption> vehicleTypes;
  final String supportPhone;
  final String supportEmail;
  final String supportHours;
  final String termsUrl;
  final String privacyUrl;
  final String driverAgreementUrl;
  final String city;
  final String currency;
  final List<String> languages;
  final String? razorpayKeyId;
  final AppVersion minSupportedVersion;
  final AppVersion latestVersion;
  final bool forceUpdate;

  factory AppRemoteConfig.fromJson(Map<String, dynamic> json) =>
      _$AppRemoteConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AppRemoteConfigToJson(this);
}
