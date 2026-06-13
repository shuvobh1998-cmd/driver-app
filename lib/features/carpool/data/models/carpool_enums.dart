import 'package:json_annotation/json_annotation.dart';

import '../../../../design_system/design_system.dart';

/// Lifecycle of a posted carpool trip (`ScheduledTripDto.status`). [unknown]
/// guards a server value the app does not yet model so it never throws.
@JsonEnum()
enum ScheduledTripStatus {
  @JsonValue('OPEN')
  open,
  @JsonValue('FULL')
  full,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('CANCELLED')
  cancelled,
  unknown;

  /// Editable only while OPEN with no bookings (the backend also enforces this).
  bool get isOpen => this == open;

  /// The trip day has begun — the driver may mark no-shows and complete it.
  bool get isInProgress => this == inProgress;

  /// Can the driver still start this trip?
  bool get canStart => this == open || this == full;

  /// Reached a final state — no more lifecycle actions.
  bool get isTerminal => this == completed || this == cancelled;

  String get label => switch (this) {
    ScheduledTripStatus.open => 'Open',
    ScheduledTripStatus.full => 'Full',
    ScheduledTripStatus.inProgress => 'In progress',
    ScheduledTripStatus.completed => 'Completed',
    ScheduledTripStatus.cancelled => 'Cancelled',
    ScheduledTripStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    ScheduledTripStatus.open => StatusTone.info,
    ScheduledTripStatus.full => StatusTone.warning,
    ScheduledTripStatus.inProgress => StatusTone.success,
    ScheduledTripStatus.completed => StatusTone.success,
    ScheduledTripStatus.cancelled => StatusTone.danger,
    ScheduledTripStatus.unknown => StatusTone.neutral,
  };
}

/// State of a single rider's booking on a carpool trip.
@JsonEnum()
enum BookingStatus {
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('CHECKED_IN')
  checkedIn,
  @JsonValue('NO_SHOW')
  noShow,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('COMPLETED')
  completed,
  unknown;

  /// A no-show can only be marked against a still-confirmed booking.
  bool get canMarkNoShow => this == confirmed || this == checkedIn;

  String get label => switch (this) {
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.checkedIn => 'Checked in',
    BookingStatus.noShow => 'No-show',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.completed => 'Completed',
    BookingStatus.unknown => '—',
  };

  StatusTone get tone => switch (this) {
    BookingStatus.confirmed => StatusTone.info,
    BookingStatus.checkedIn => StatusTone.success,
    BookingStatus.noShow => StatusTone.danger,
    BookingStatus.cancelled => StatusTone.danger,
    BookingStatus.completed => StatusTone.success,
    BookingStatus.unknown => StatusTone.neutral,
  };
}

/// Settlement state of a booking's seat payment.
@JsonEnum()
enum BookingPaymentStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('PAID')
  paid,
  @JsonValue('FAILED')
  failed,
  @JsonValue('REFUNDED')
  refunded,
  unknown;

  String get label => switch (this) {
    BookingPaymentStatus.pending => 'Payment pending',
    BookingPaymentStatus.paid => 'Paid',
    BookingPaymentStatus.failed => 'Payment failed',
    BookingPaymentStatus.refunded => 'Refunded',
    BookingPaymentStatus.unknown => '—',
  };
}

/// Who a carpool seat is offered to (a trip preference).
@JsonEnum()
enum GenderPreference {
  @JsonValue('ANY')
  any,
  @JsonValue('MALE')
  male,
  @JsonValue('FEMALE')
  female;

  String get wireValue => switch (this) {
    GenderPreference.any => 'ANY',
    GenderPreference.male => 'MALE',
    GenderPreference.female => 'FEMALE',
  };

  String get label => switch (this) {
    GenderPreference.any => 'Anyone',
    GenderPreference.male => 'Men only',
    GenderPreference.female => 'Women only',
  };
}

/// Origin of a chat message — a normal user message or a system notice.
@JsonEnum()
enum ChatMessageType {
  @JsonValue('USER')
  user,
  @JsonValue('SYSTEM')
  system,
  unknown,
}
