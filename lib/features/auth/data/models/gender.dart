import 'package:json_annotation/json_annotation.dart';

/// User gender, matching the backend enum. [unknown] guards against a value the
/// app doesn't yet know about (json_serializable `unknownEnumValue`).
@JsonEnum()
enum Gender {
  @JsonValue('MALE')
  male,
  @JsonValue('FEMALE')
  female,
  @JsonValue('OTHER')
  other,
  @JsonValue('PREFER_NOT_TO_SAY')
  preferNotToSay,
  unknown;

  String get wireValue => switch (this) {
    Gender.male => 'MALE',
    Gender.female => 'FEMALE',
    Gender.other => 'OTHER',
    Gender.preferNotToSay => 'PREFER_NOT_TO_SAY',
    Gender.unknown => 'PREFER_NOT_TO_SAY',
  };

  String get label => switch (this) {
    Gender.male => 'Male',
    Gender.female => 'Female',
    Gender.other => 'Other',
    Gender.preferNotToSay => 'Prefer not to say',
    Gender.unknown => '—',
  };
}

/// Account status from the backend.
@JsonEnum()
enum AccountStatus {
  @JsonValue('ACTIVE')
  active,
  @JsonValue('SUSPENDED')
  suspended,
  @JsonValue('BANNED')
  banned,
  @JsonValue('DELETED')
  deleted,
  unknown,
}
