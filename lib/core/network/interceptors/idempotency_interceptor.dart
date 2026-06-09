import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Adds an `Idempotency-Key` to every money/state-changing POST so retries are
/// safe (go-online, accept, cash-collected, payout, …).
///
/// A caller may pre-set the header (e.g. to reuse a key across an explicit
/// retry); this interceptor only fills it in when absent.
class IdempotencyInterceptor extends Interceptor {
  IdempotencyInterceptor([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static const String header = 'Idempotency-Key';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final isMutating = options.method == 'POST' || options.method == 'PUT';
    if (isMutating && !options.headers.containsKey(header)) {
      options.headers[header] = _uuid.v4();
    }
    handler.next(options);
  }
}
