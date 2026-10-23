import 'package:json_annotation/json_annotation.dart';

part 'data_export.g.dart';

/// A ready-to-download personal-data archive from
/// `POST /users/me/account/data-export`. [url] is a private, time-limited link
/// (valid until [expiresAt]); the backend also sends it to the inbox.
@JsonSerializable(createToJson: false)
class DataExport {
  const DataExport({required this.url, this.sizeBytes, this.expiresAt});

  final String url;
  final int? sizeBytes;
  final DateTime? expiresAt;

  /// Human-readable archive size, e.g. "48 KB" or "1.2 MB".
  String? get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory DataExport.fromJson(Map<String, dynamic> json) =>
      _$DataExportFromJson(json);
}
