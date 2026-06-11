import 'package:json_annotation/json_annotation.dart';

part 'account_deletion.g.dart';

/// State of an account-deletion request from
/// `POST /users/me/account/delete-request[/cancel]`. While [pending], the
/// account is scheduled for deletion at [scheduledAt] and can be cancelled.
@JsonSerializable()
class AccountDeletion {
  const AccountDeletion({
    required this.pending,
    this.requestedAt,
    this.scheduledAt,
  });

  final bool pending;
  final DateTime? requestedAt;
  final DateTime? scheduledAt;

  factory AccountDeletion.fromJson(Map<String, dynamic> json) =>
      _$AccountDeletionFromJson(json);
  Map<String, dynamic> toJson() => _$AccountDeletionToJson(this);
}
