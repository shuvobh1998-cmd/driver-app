import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import 'models/safety.dart';

/// Transport over the trip-scoped safety endpoints (D7): SOS + live share.
/// State-changing POSTs carry an `Idempotency-Key` automatically.
class SafetyApi {
  SafetyApi(this._dio);

  final Dio _dio;

  /// Raises an SOS on the active trip, optionally with the current position and
  /// a short note. Returns how many emergency contacts were alerted.
  Future<SosEvent> raiseSos(
    String tripId, {
    double? lat,
    double? lng,
    String? note,
  }) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/sos',
      data: {'lat': ?lat, 'lng': ?lng, 'note': ?note},
    );
    return res.unwrap(SosEvent.fromJson);
  }

  /// Creates a live-tracking share link, SMS'ing it to [recipientPhones].
  Future<TripShare> share(
    String tripId, {
    List<String> recipientPhones = const [],
    int? expiresInHours,
  }) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/share',
      data: {
        if (recipientPhones.isNotEmpty) 'recipientPhones': recipientPhones,
        'expiresInHours': ?expiresInHours,
      },
    );
    return res.unwrap(TripShare.fromJson);
  }

  /// Active share links for a trip.
  Future<List<TripShare>> shares(String tripId) async {
    final res = await _dio.get<dynamic>('/trips/$tripId/shares');
    return res.unwrapList(TripShare.fromJson);
  }

  /// Revokes a share link.
  Future<void> revoke(String tripId, String shareId) async {
    await _dio.delete<dynamic>('/trips/$tripId/share/$shareId');
  }
}
