import 'package:json_annotation/json_annotation.dart';

import '../../../../design_system/design_system.dart';

part 'driver_state.g.dart';

/// The driver's live availability, from `GET /drivers/me/state` and the
/// online/offline/location endpoints. [unknown] guards a value the app does
/// not yet model.
@JsonEnum()
enum DriverStatus {
  @JsonValue('OFFLINE')
  offline,
  @JsonValue('ONLINE')
  online,
  @JsonValue('ON_TRIP')
  onTrip,
  @JsonValue('BREAK')
  onBreak,
  unknown;

  /// True while the driver is available to the matching engine (pin is live).
  bool get isLive => this == online || this == onTrip;

  String get label => switch (this) {
    DriverStatus.offline => 'Offline',
    DriverStatus.online => 'Online',
    DriverStatus.onTrip => 'On a trip',
    DriverStatus.onBreak => 'On a break',
    DriverStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    DriverStatus.offline => StatusTone.neutral,
    DriverStatus.online => StatusTone.success,
    DriverStatus.onTrip => StatusTone.info,
    DriverStatus.onBreak => StatusTone.warning,
    DriverStatus.unknown => StatusTone.neutral,
  };
}

/// A last-known position `{lat, lng}`, per the handoff location convention.
@JsonSerializable()
class DriverLocation {
  const DriverLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory DriverLocation.fromJson(Map<String, dynamic> json) =>
      _$DriverLocationFromJson(json);

  Map<String, dynamic> toJson() => _$DriverLocationToJson(this);
}

/// The single server-truth driver state. WS only notifies; this REST shape is
/// reconciled after every transition and on reconnect.
@JsonSerializable(createToJson: false)
class DriverState {
  const DriverState({
    required this.status,
    this.vehicleId,
    this.location,
    this.locationUpdatedAt,
    this.wentOnlineAt,
  });

  @JsonKey(unknownEnumValue: DriverStatus.unknown)
  final DriverStatus status;
  final String? vehicleId;
  final DriverLocation? location;
  final DateTime? locationUpdatedAt;
  final DateTime? wentOnlineAt;

  bool get isOnline => status.isLive;

  factory DriverState.fromJson(Map<String, dynamic> json) =>
      _$DriverStateFromJson(json);
}
