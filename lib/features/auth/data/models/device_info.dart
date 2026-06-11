import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'device_info.g.dart';

/// Sent on signup / login / verify so the Sessions screen shows a meaningful
/// device name. All fields are optional on the wire.
@JsonSerializable(includeIfNull: false)
class DeviceInfo {
  const DeviceInfo({this.model, this.os, this.userAgent});

  final String? model;
  final String? os;
  final String? userAgent;

  /// Best-effort device descriptor from the OS. Kept dependency-free; a richer
  /// model/name can be wired via `device_info_plus` later if needed.
  factory DeviceInfo.current() {
    return DeviceInfo(
      model: Platform.operatingSystem,
      os: Platform.operatingSystemVersion,
      userAgent: 'rideshare-driver/1.0.0 (${Platform.operatingSystem})',
    );
  }

  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
}
