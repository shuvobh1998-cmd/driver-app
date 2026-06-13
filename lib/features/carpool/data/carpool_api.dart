import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/booking.dart';
import 'models/carpool_enums.dart';
import 'models/scheduled_trip.dart';

/// Transport over the scheduled-carpool + bookings endpoints (D6). Lifecycle
/// POSTs (start, complete, cancel, no-show) carry an `Idempotency-Key`
/// automatically via the interceptor, so a retried tap is safe.
class CarpoolApi {
  CarpoolApi(this._dio);

  final Dio _dio;

  /// Posts a new scheduled carpool trip.
  Future<ScheduledTrip> create({
    required LatLngPoint origin,
    String? originAddress,
    required LatLngPoint destination,
    String? destAddress,
    required DateTime departureAt,
    required String vehicleId,
    required int totalSeats,
    required int pricePerSeat,
    String? notes,
    TripPreferences? preferences,
  }) async {
    final res = await _dio.post<dynamic>(
      '/scheduled-trips',
      data: {
        'origin': origin.toJson(),
        if (originAddress != null && originAddress.isNotEmpty)
          'originAddress': originAddress,
        'destination': destination.toJson(),
        if (destAddress != null && destAddress.isNotEmpty)
          'destAddress': destAddress,
        'departureAt': departureAt.toUtc().toIso8601String(),
        'vehicleId': vehicleId,
        'totalSeats': totalSeats,
        'pricePerSeat': pricePerSeat,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (preferences != null) 'preferences': preferences.toJson(),
      },
    );
    return res.unwrap(ScheduledTrip.fromJson);
  }

  /// The driver's own posted trips, newest departure first, optionally filtered.
  Future<List<ScheduledTrip>> mine({
    int page = 1,
    int pageSize = 20,
    ScheduledTripStatus? status,
  }) async {
    final res = await _dio.get<dynamic>(
      '/scheduled-trips/me',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': _statusWire(status),
      },
    );
    return res.unwrapList(ScheduledTrip.fromJson);
  }

  /// Full detail for one posted trip.
  Future<ScheduledTrip> detail(String id) async {
    final res = await _dio.get<dynamic>('/scheduled-trips/$id');
    return res.unwrap(ScheduledTrip.fromJson);
  }

  /// Edits a trip — only allowed while OPEN with no bookings.
  Future<ScheduledTrip> update(
    String id, {
    DateTime? departureAt,
    int? totalSeats,
    int? pricePerSeat,
    String? notes,
    TripPreferences? preferences,
  }) async {
    final res = await _dio.patch<dynamic>(
      '/scheduled-trips/$id',
      data: {
        if (departureAt != null)
          'departureAt': departureAt.toUtc().toIso8601String(),
        'totalSeats': ?totalSeats,
        'pricePerSeat': ?pricePerSeat,
        'notes': ?notes,
        if (preferences != null) 'preferences': preferences.toJson(),
      },
    );
    return res.unwrap(ScheduledTrip.fromJson);
  }

  /// Bookings made on the driver's trip.
  Future<List<Booking>> tripBookings(String id) async {
    final res = await _dio.get<dynamic>('/scheduled-trips/$id/bookings');
    return res.unwrapList(Booking.fromJson);
  }

  /// Begins the trip day → IN_PROGRESS.
  Future<ScheduledTrip> start(String id) async {
    final res = await _dio.post<dynamic>(
      '/scheduled-trips/$id/start',
      data: const <String, dynamic>{},
    );
    return res.unwrap(ScheduledTrip.fromJson);
  }

  /// Completes the trip.
  Future<ScheduledTrip> complete(String id) async {
    final res = await _dio.post<dynamic>(
      '/scheduled-trips/$id/complete',
      data: const <String, dynamic>{},
    );
    return res.unwrap(ScheduledTrip.fromJson);
  }

  /// Cancels the trip — refunds every booking 100%.
  Future<ScheduledTrip> cancel(String id, {String? reason}) async {
    final res = await _dio.post<dynamic>(
      '/scheduled-trips/$id/cancel',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    return res.unwrap(ScheduledTrip.fromJson);
  }

  /// Marks a rider's booking as a no-show.
  Future<Booking> markNoShow(String bookingId) async {
    final res = await _dio.post<dynamic>(
      '/bookings/$bookingId/no-show',
      data: const <String, dynamic>{},
    );
    return res.unwrap(Booking.fromJson);
  }

  static String _statusWire(ScheduledTripStatus status) => switch (status) {
    ScheduledTripStatus.open => 'OPEN',
    ScheduledTripStatus.full => 'FULL',
    ScheduledTripStatus.inProgress => 'IN_PROGRESS',
    ScheduledTripStatus.completed => 'COMPLETED',
    ScheduledTripStatus.cancelled => 'CANCELLED',
    ScheduledTripStatus.unknown => 'OPEN',
  };
}
