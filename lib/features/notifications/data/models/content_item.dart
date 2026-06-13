import 'package:json_annotation/json_annotation.dart';

part 'content_item.g.dart';

/// Kind of CMS content served by `/content/*`.
@JsonEnum()
enum ContentType {
  @JsonValue('FAQ')
  faq,
  @JsonValue('ARTICLE')
  article,
  @JsonValue('LEGAL')
  legal,
  unknown,
}

/// A help/legal content item (`GET /content/faq`, `/content/articles/:slug`,
/// `/content/legal/:slug`). [body] is Markdown; [category] groups FAQ entries.
@JsonSerializable(createToJson: false)
class ContentItem {
  const ContentItem({
    required this.type,
    required this.slug,
    required this.locale,
    required this.title,
    required this.body,
    required this.order,
    required this.updatedAt,
    this.category,
  });

  @JsonKey(unknownEnumValue: ContentType.unknown)
  final ContentType type;
  final String slug;
  final String locale;
  final String title;

  /// Markdown source. Rendered as plain text today (no Markdown dependency).
  final String body;

  /// FAQ grouping label, when present.
  final String? category;
  final int order;
  final DateTime updatedAt;

  factory ContentItem.fromJson(Map<String, dynamic> json) =>
      _$ContentItemFromJson(json);
}
