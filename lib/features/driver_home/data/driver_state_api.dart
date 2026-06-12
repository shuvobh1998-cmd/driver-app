import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/driver_state.dart';

/// Transport over the driver online/location endpoints (D3). Returns the
/// authoritative [DriverState] so callers reconcile against server truth.
class DriverStateApi {
  DriverStateApi(this._dio);

  final Dio _dio;

  /// Goes online with [vehicleId] (must be an ACTIVE, owned vehicle). The
  /// interceptor adds an `Idempotency-Key`, so a retried tap is safe.
  Future<DriverState> goOnline(String vehicleId) async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/online',
      data: {'vehicleId': vehicleId},
    );
    return res.unwrap(DriverState.fromJson);
  }

  /// Goes offline. Sends an empty JSON object since the client always sets a
  /// JSON content-type and the backend rejects an empty body for one.
  Future<DriverState> goOffline() async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/offline',
      data: const <String, dynamic>{},
    );
    return res.unwrap(DriverState.fromJson);
  }

  /// Reports a single location ping while online.
  Future<DriverState> reportLocation({
    required double lat,
    required double lng,
    double? speed,
    double? bearing,
  }) async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/location',
      data: {'lat': lat, 'lng': lng, 'speed': ?speed, 'bearing': ?bearing},
    );
    return res.unwrap(DriverState.fromJson);
  }

  Future<DriverState> getState() async {
    final res = await _dio.get<dynamic>('/drivers/me/state');
    return res.unwrap(DriverState.fromJson);
  }
}
