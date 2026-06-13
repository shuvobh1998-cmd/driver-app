import 'package:json_annotation/json_annotation.dart';

import '../../../../design_system/design_system.dart';

part 'support.g.dart';

/// Category of a support ticket.
@JsonEnum()
enum TicketCategory {
  @JsonValue('PAYMENT_ISSUE')
  paymentIssue,
  @JsonValue('DRIVER_BEHAVIOR')
  driverBehavior,
  @JsonValue('RIDER_BEHAVIOR')
  riderBehavior,
  @JsonValue('SAFETY')
  safety,
  @JsonValue('LOST_ITEM')
  lostItem,
  @JsonValue('APP_BUG')
  appBug,
  @JsonValue('KYC')
  kyc,
  @JsonValue('OTHER')
  other;

  /// The wire value sent in the `category` field.
  String get wireValue => switch (this) {
    TicketCategory.paymentIssue => 'PAYMENT_ISSUE',
    TicketCategory.driverBehavior => 'DRIVER_BEHAVIOR',
    TicketCategory.riderBehavior => 'RIDER_BEHAVIOR',
    TicketCategory.safety => 'SAFETY',
    TicketCategory.lostItem => 'LOST_ITEM',
    TicketCategory.appBug => 'APP_BUG',
    TicketCategory.kyc => 'KYC',
    TicketCategory.other => 'OTHER',
  };

  String get label => switch (this) {
    TicketCategory.paymentIssue => 'Payment issue',
    TicketCategory.driverBehavior => 'My behaviour',
    TicketCategory.riderBehavior => 'Rider behaviour',
    TicketCategory.safety => 'Safety',
    TicketCategory.lostItem => 'Lost item',
    TicketCategory.appBug => 'App bug',
    TicketCategory.kyc => 'KYC / documents',
    TicketCategory.other => 'Something else',
  };

  /// The categories a driver can pick when opening a general ticket
  /// (lost-item has its own dedicated flow).
  static List<TicketCategory> get selectable => const [
    TicketCategory.paymentIssue,
    TicketCategory.driverBehavior,
    TicketCategory.riderBehavior,
    TicketCategory.safety,
    TicketCategory.appBug,
    TicketCategory.kyc,
    TicketCategory.other,
  ];
}

/// Workflow state of a support ticket.
@JsonEnum()
enum TicketStatus {
  @JsonValue('OPEN')
  open,
  @JsonValue('PENDING')
  pending,
  @JsonValue('RESOLVED')
  resolved,
  @JsonValue('CLOSED')
  closed,
  unknown;

  /// The ticket can still be replied to (not resolved/closed).
  bool get isActive => this == open || this == pending;

  String get label => switch (this) {
    TicketStatus.open => 'Open',
    TicketStatus.pending => 'Awaiting reply',
    TicketStatus.resolved => 'Resolved',
    TicketStatus.closed => 'Closed',
    TicketStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    TicketStatus.open => StatusTone.info,
    TicketStatus.pending => StatusTone.warning,
    TicketStatus.resolved => StatusTone.success,
    TicketStatus.closed => StatusTone.neutral,
    TicketStatus.unknown => StatusTone.neutral,
  };
}

/// One message in a ticket thread. [isStaff] is true for a support-agent reply.
@JsonSerializable(createToJson: false)
class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.body,
    required this.isStaff,
    required this.createdAt,
  });

  final String id;
  final String body;
  final bool isStaff;
  final DateTime createdAt;

  factory TicketMessage.fromJson(Map<String, dynamic> json) =>
      _$TicketMessageFromJson(json);
}

/// A support ticket (`POST/GET /support/tickets…`). The thread is populated on
/// the detail endpoint; the list endpoint omits [messages].
@JsonSerializable(createToJson: false)
class Ticket {
  const Ticket({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.tripId,
    this.messages = const [],
  });

  final String id;

  @JsonKey(unknownEnumValue: TicketCategory.other)
  final TicketCategory category;
  final String subject;
  final String description;

  @JsonKey(unknownEnumValue: TicketStatus.unknown)
  final TicketStatus status;
  final String? tripId;

  @JsonKey(defaultValue: [])
  final List<TicketMessage> messages;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory Ticket.fromJson(Map<String, dynamic> json) => _$TicketFromJson(json);
}
