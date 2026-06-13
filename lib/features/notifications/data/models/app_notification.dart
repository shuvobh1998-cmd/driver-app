import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_notification.g.dart';

/// An in-app notification (`GET /notifications`, `POST /notifications/:id/read`).
/// [deepLink] is an internal route path the inbox can navigate to on tap;
/// [data] carries the raw FCM payload for screens that need extra ids.
@JsonSerializable(createToJson: false)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.deepLink,
    this.data = const {},
  });

  final String id;

  /// Server category string (e.g. `TRIP`, `PAYMENT`, `SOS`, `SUPPORT`). Kept as
  /// a raw string — the app maps known values to an icon and tolerates new ones.
  final String type;
  final String title;
  final String body;

  /// Internal route to open on tap (e.g. `/trips/trp_123`), when present.
  final String? deepLink;

  @JsonKey(defaultValue: {})
  final Map<String, dynamic> data;

  final bool read;
  final DateTime createdAt;

  /// An icon for the notification's [type], with a sensible default.
  IconData get icon => switch (type.toUpperCase()) {
    'TRIP' || 'TRIP_OFFER' || 'SCHEDULED_TRIP' => Icons.directions_car,
    'PAYMENT' || 'PAYOUT' || 'WALLET' => Icons.account_balance_wallet,
    'SOS' || 'SAFETY' => Icons.emergency,
    'SUPPORT' || 'TICKET' => Icons.support_agent,
    'CHAT' || 'MESSAGE' => Icons.chat_bubble,
    'KYC' || 'VEHICLE' => Icons.verified_user,
    _ => Icons.notifications,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
