import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/trip.dart';
import 'models/trip_enums.dart';

/// Transport over the driver trip-offer + lifecycle endpoints (D4). Every
/// lifecycle call returns the authoritative [Trip] so callers reconcile against
/// server truth — **WS is a notifier, REST is the truth.**
///
/// State-changing POSTs (accept, arrived, start, end, cancel) carry an
/// `Idempotency-Key` automatically via the interceptor, so a retried tap is safe.
class TripsApi {
  TripsApi(this._dio);

  final Dio _dio;

  /// Accepts an offer; the backend creates the trip and returns its id + status.
  Future<AcceptOfferResult> acceptOffer(String offerId) async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/trip-offers/$offerId/accept',
      data: const <String, dynamic>{},
    );
    return res.unwrap(AcceptOfferResult.fromJson);
  }

  /// Declines an offer so matching can re-assign it.
  Future<void> declineOffer(String offerId) async {
    await _dio.post<dynamic>(
      '/drivers/me/trip-offers/$offerId/decline',
      data: const <String, dynamic>{},
    );
  }

  /// The driver's active trip (ACCEPTED/ARRIVED/STARTED), or null when none.
  Future<Trip?> currentTrip() async {
    try {
      final res = await _dio.get<dynamic>('/drivers/me/trips/current');
      // A success envelope with a null `data` means "no active trip".
      final body = res.data;
      final data = body is Map ? body['data'] : body;
      if (data == null) return null;
      return res.unwrap(Trip.fromJson);
    } on DioException catch (e) {
      // No active trip surfaces as a 404 on some deployments — treat as null.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Full trip detail by id.
  Future<Trip> tripDetail(String tripId) async {
    final res = await _dio.get<dynamic>('/trips/$tripId');
    return res.unwrap(Trip.fromJson);
  }

  /// One page of trip history, newest first, optionally filtered by status.
  Future<List<Trip>> history({
    int page = 1,
    int pageSize = 20,
    TripStatus? status,
  }) async {
    final res = await _dio.get<dynamic>(
      '/drivers/me/trips',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': _statusWire(status),
      },
    );
    return res.unwrapList(Trip.fromJson);
  }

  /// Marks the driver as arrived at the pickup.
  Future<Trip> arrived(String tripId) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/arrived',
      data: const <String, dynamic>{},
    );
    return res.unwrap(Trip.fromJson);
  }

  /// Starts the trip with the rider's 4-digit OTP. Wrong → `OTP_INVALID`,
  /// missing → `OTP_REQUIRED`.
  Future<Trip> start(String tripId, {required String otp}) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/start',
      data: {'otp': otp},
    );
    return res.unwrap(Trip.fromJson);
  }

  /// Ends the trip; the backend finalises distance, duration and fare.
  Future<Trip> end(String tripId) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/end',
      data: const <String, dynamic>{},
    );
    return res.unwrap(Trip.fromJson);
  }

  /// Cancels the trip (pre-start) with an optional free-text reason.
  Future<Trip> cancel(String tripId, {String? reason}) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/cancel',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    return res.unwrap(Trip.fromJson);
  }

  /// Rates the rider 1–5 with an optional comment. Re-rating → `ALREADY_RATED`.
  Future<Trip> rateRider(
    String tripId, {
    required int rating,
    String? comment,
  }) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/rate-rider',
      data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return res.unwrap(Trip.fromJson);
  }

  /// Files a problem report against the trip.
  Future<TripReport> report(
    String tripId, {
    required ReportCategory category,
    required String description,
  }) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/report',
      data: {'category': category.wireValue, 'description': description},
    );
    return res.unwrap(TripReport.fromJson);
  }

  static String _statusWire(TripStatus status) => switch (status) {
    TripStatus.requested => 'REQUESTED',
    TripStatus.accepted => 'ACCEPTED',
    TripStatus.arrived => 'ARRIVED',
    TripStatus.started => 'STARTED',
    TripStatus.ended => 'ENDED',
    TripStatus.cancelled => 'CANCELLED',
    TripStatus.unknown => 'ENDED',
  };
}
