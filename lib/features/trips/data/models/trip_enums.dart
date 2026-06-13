import 'package:json_annotation/json_annotation.dart';

import '../../../../design_system/design_system.dart';

/// Lifecycle state of a trip, from the backend `status` enum. [unknown] guards
/// a value the app does not yet model so an unexpected status never throws.
@JsonEnum()
enum TripStatus {
  @JsonValue('REQUESTED')
  requested,
  @JsonValue('ACCEPTED')
  accepted,
  @JsonValue('ARRIVED')
  arrived,
  @JsonValue('STARTED')
  started,
  @JsonValue('ENDED')
  ended,
  @JsonValue('CANCELLED')
  cancelled,
  unknown;

  /// The driver is engaged on this trip (may stream `trip.location`).
  bool get isActive => this == accepted || this == arrived || this == started;

  /// The trip has reached a final state — no more lifecycle actions.
  bool get isTerminal => this == ended || this == cancelled;

  String get label => switch (this) {
    TripStatus.requested => 'Requested',
    TripStatus.accepted => 'Heading to pickup',
    TripStatus.arrived => 'At pickup',
    TripStatus.started => 'In progress',
    TripStatus.ended => 'Completed',
    TripStatus.cancelled => 'Cancelled',
    TripStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    TripStatus.requested => StatusTone.neutral,
    TripStatus.accepted => StatusTone.info,
    TripStatus.arrived => StatusTone.info,
    TripStatus.started => StatusTone.success,
    TripStatus.ended => StatusTone.success,
    TripStatus.cancelled => StatusTone.danger,
    TripStatus.unknown => StatusTone.neutral,
  };
}

/// How the rider pays for the trip.
@JsonEnum()
enum PaymentMethod {
  @JsonValue('CASH')
  cash,
  @JsonValue('UPI')
  upi,
  @JsonValue('CARD')
  card,
  unknown;

  String get label => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.upi => 'UPI',
    PaymentMethod.card => 'Card',
    PaymentMethod.unknown => '—',
  };
}

/// Settlement state of the trip's fare.
@JsonEnum()
enum PaymentStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('PAID')
  paid,
  @JsonValue('FAILED')
  failed,
  @JsonValue('REFUNDED')
  refunded,
  unknown,
}

/// Who cancelled a trip, when it was cancelled.
@JsonEnum()
enum CancelActor {
  @JsonValue('RIDER')
  rider,
  @JsonValue('DRIVER')
  driver,
  @JsonValue('SYSTEM')
  system,
  @JsonValue('ADMIN')
  admin,
  unknown;

  String get label => switch (this) {
    CancelActor.rider => 'rider',
    CancelActor.driver => 'you',
    CancelActor.system => 'the system',
    CancelActor.admin => 'support',
    CancelActor.unknown => 'someone',
  };
}

/// Categories for a trip problem report (`POST /trips/:id/report`).
@JsonEnum()
enum ReportCategory {
  @JsonValue('SAFETY')
  safety,
  @JsonValue('RIDER_BEHAVIOR')
  riderBehavior,
  @JsonValue('PAYMENT_ISSUE')
  paymentIssue,
  @JsonValue('LOST_ITEM')
  lostItem,
  @JsonValue('CLEANLINESS')
  cleanliness,
  @JsonValue('OTHER')
  other;

  /// The wire value sent in the `category` field.
  String get wireValue => switch (this) {
    ReportCategory.safety => 'SAFETY',
    ReportCategory.riderBehavior => 'RIDER_BEHAVIOR',
    ReportCategory.paymentIssue => 'PAYMENT_ISSUE',
    ReportCategory.lostItem => 'LOST_ITEM',
    ReportCategory.cleanliness => 'CLEANLINESS',
    ReportCategory.other => 'OTHER',
  };

  String get label => switch (this) {
    ReportCategory.safety => 'Safety concern',
    ReportCategory.riderBehavior => 'Rider behaviour',
    ReportCategory.paymentIssue => 'Payment issue',
    ReportCategory.lostItem => 'Lost item',
    ReportCategory.cleanliness => 'Cleanliness',
    ReportCategory.other => 'Something else',
  };
}
