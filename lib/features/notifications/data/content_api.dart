import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/content_item.dart';

/// Transport over the public CMS endpoints (D7): FAQ, articles, legal pages.
/// These are unauthenticated, but the shared client adds the bearer harmlessly.
class ContentApi {
  ContentApi(this._dio);

  final Dio _dio;

  /// FAQ entries, localized and ordered.
  Future<List<ContentItem>> faq({String? locale}) async {
    final res = await _dio.get<dynamic>(
      '/content/faq',
      queryParameters: {'locale': ?locale},
    );
    return res.unwrapList(ContentItem.fromJson);
  }

  /// A help article by slug.
  Future<ContentItem> article(String slug, {String? locale}) async {
    final res = await _dio.get<dynamic>(
      '/content/articles/$slug',
      queryParameters: {'locale': ?locale},
    );
    return res.unwrap(ContentItem.fromJson);
  }

  /// A legal document by slug (terms, privacy, …).
  Future<ContentItem> legal(String slug, {String? locale}) async {
    final res = await _dio.get<dynamic>(
      '/content/legal/$slug',
      queryParameters: {'locale': ?locale},
    );
    return res.unwrap(ContentItem.fromJson);
  }
}
