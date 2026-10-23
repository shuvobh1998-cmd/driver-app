import 'package:dio/dio.dart';

/// Watches for `426 FORCE_UPDATE_REQUIRED`, which the backend returns from
/// **any** endpoint once this build is below the platform's minimum version.
/// Every later call would fail the same way, so [onRequired] raises the
/// app-wide blocking update screen; the error still propagates to the caller.
class ForceUpdateInterceptor extends Interceptor {
  ForceUpdateInterceptor(this._onRequired);

  final void Function() _onRequired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 426) _onRequired();
    handler.next(err);
  }
}
