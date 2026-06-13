import 'package:json_annotation/json_annotation.dart';

part 'safety.g.dart';

/// Result of raising an SOS during a trip (`POST /trips/:id/sos`).
/// [contactsNotified] is how many emergency contacts received an alert SMS.
@JsonSerializable(createToJson: false)
class SosEvent {
  const SosEvent({
    required this.id,
    required this.contactsNotified,
    required this.createdAt,
    this.tripId,
  });

  final String id;
  final String? tripId;
  final int contactsNotified;
  final DateTime createdAt;

  factory SosEvent.fromJson(Map<String, dynamic> json) =>
      _$SosEventFromJson(json);
}

/// A live-tracking share link for a trip (`POST/GET /trips/:id/share[s]`).
/// [url] is the public tracker; [expiresAt] is null when the link never expires.
@JsonSerializable(createToJson: false)
class TripShare {
  const TripShare({
    required this.id,
    required this.url,
    required this.recipientsNotified,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String url;

  /// How many recipients were SMS'd the link when it was created.
  final int recipientsNotified;
  final DateTime? expiresAt;
  final DateTime createdAt;

  factory TripShare.fromJson(Map<String, dynamic> json) =>
      _$TripShareFromJson(json);
}
