import 'package:json_annotation/json_annotation.dart';

part 'user_preferences.g.dart';

/// User preferences from `GET/PATCH /users/me/preferences`. `language` is one
/// of the app locales (en/bn/hi).
@JsonSerializable()
class UserPreferences {
  const UserPreferences({
    required this.language,
    required this.marketingPush,
    required this.marketingSms,
  });

  final String language;
  final bool marketingPush;
  final bool marketingSms;

  UserPreferences copyWith({
    String? language,
    bool? marketingPush,
    bool? marketingSms,
  }) => UserPreferences(
    language: language ?? this.language,
    marketingPush: marketingPush ?? this.marketingPush,
    marketingSms: marketingSms ?? this.marketingSms,
  );

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$UserPreferencesToJson(this);
}
