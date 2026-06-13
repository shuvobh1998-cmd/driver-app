import 'package:dio/dio.dart';
import 'package:driver_app/features/onboarding_kyc/data/models/onboarding_enums.dart';
import 'package:driver_app/features/trips/data/models/trip_enums.dart';
import 'package:driver_app/features/trips/data/trips_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the last request and replies with a canned envelope, so we can assert
/// both the parse and what the client actually sent.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.statusCode = 200});
  final String body;
  final int statusCode;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(TripsApi, _StubAdapter) _apiWith(String body, {int statusCode = 200}) {
  final adapter = _StubAdapter(body, statusCode: statusCode);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter
    // Don't throw on the 404 we use to signal "no active trip".
    ..options.validateStatus = (_) => true;
  return (TripsApi(dio), adapter);
}

const _tripEnvelope =
    '{"success":true,"data":{'
    '"publicId":"trp_abc123",'
    '"status":"STARTED",'
    '"vehicleType":"CAR",'
    '"pickup":{"lat":22.5726,"lng":88.3639,"address":"Park Street"},'
    '"drop":{"lat":22.58,"lng":88.40,"address":"Salt Lake"},'
    '"paymentMethod":"CASH",'
    '"paymentStatus":"PENDING",'
    '"estimatedFare":11203,'
    '"totalFare":11500,'
    '"actualDistance":5120,'
    '"actualDuration":760,'
    '"fareBreakdown":{"baseFare":2500,"distanceFare":6000,"timeFare":1200,'
    '"platformFee":970,"gst":533,"total":11203},'
    '"riderRating":null,'
    '"createdAt":"2026-06-02T10:00:00.000Z"}}';

void main() {
  test('currentTrip parses the trip envelope', () async {
    final (api, _) = _apiWith(_tripEnvelope);

    final trip = await api.currentTrip();

    expect(trip, isNotNull);
    expect(trip!.publicId, 'trp_abc123');
    expect(trip.status, TripStatus.started);
    expect(trip.vehicleType, VehicleType.car);
    expect(trip.pickup.address, 'Park Street');
    expect(trip.paymentMethod, PaymentMethod.cash);
    expect(trip.totalFare, 11500);
    expect(trip.actualDistance, 5120);
    expect(trip.fareBreakdown?.total, 11203);
    expect(trip.isRated, isFalse);
    expect(trip.displayFare, 11500);
  });

  test('currentTrip returns null on a null data envelope', () async {
    final (api, _) = _apiWith('{"success":true,"data":null}');
    expect(await api.currentTrip(), isNull);
  });

  test('currentTrip returns null on a 404 (no active trip)', () async {
    final (api, _) = _apiWith(
      '{"success":false,"error":{"code":"NOT_FOUND","message":"none"}}',
      statusCode: 404,
    );
    expect(await api.currentTrip(), isNull);
  });

  test('acceptOffer posts to the offer path and parses the result', () async {
    final (api, adapter) = _apiWith(
      '{"success":true,"data":{"tripPublicId":"trp_xyz","status":"ACCEPTED"}}',
    );

    final result = await api.acceptOffer('off_123');

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/drivers/me/trip-offers/off_123/accept');
    expect(result.tripPublicId, 'trp_xyz');
    expect(result.status, TripStatus.accepted);
  });

  test('start sends the OTP in the body', () async {
    final (api, adapter) = _apiWith(_tripEnvelope);

    await api.start('trp_abc123', otp: '4821');

    expect(adapter.lastRequest?.path, '/trips/trp_abc123/start');
    expect(adapter.lastRequest?.data, {'otp': '4821'});
  });

  test('cancel omits an empty reason', () async {
    final (api, adapter) = _apiWith(_tripEnvelope);

    await api.cancel('trp_abc123', reason: '');

    expect(adapter.lastRequest?.data, const <String, dynamic>{});
  });

  test('rateRider includes the comment only when present', () async {
    final (api, adapter) = _apiWith(_tripEnvelope);

    await api.rateRider('trp_abc123', rating: 5);
    final data = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(data['rating'], 5);
    expect(data.containsKey('comment'), isFalse);
  });

  test('history forwards pagination + status as query params', () async {
    final (api, adapter) = _apiWith('{"success":true,"data":[]}');

    await api.history(page: 2, pageSize: 10, status: TripStatus.ended);

    expect(adapter.lastRequest?.path, '/drivers/me/trips');
    expect(adapter.lastRequest?.queryParameters['page'], 2);
    expect(adapter.lastRequest?.queryParameters['pageSize'], 10);
    expect(adapter.lastRequest?.queryParameters['status'], 'ENDED');
  });
}
