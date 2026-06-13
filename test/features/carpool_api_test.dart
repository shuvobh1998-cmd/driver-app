import 'package:dio/dio.dart';
import 'package:driver_app/features/carpool/data/carpool_api.dart';
import 'package:driver_app/features/carpool/data/chat_api.dart';
import 'package:driver_app/features/carpool/data/models/carpool_enums.dart';
import 'package:driver_app/features/carpool/data/models/scheduled_trip.dart';
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

(Dio, _StubAdapter) _dioWith(String body, {int statusCode = 200}) {
  final adapter = _StubAdapter(body, statusCode: statusCode);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter
    ..options.validateStatus = (_) => true;
  return (dio, adapter);
}

const _tripJson =
    '{"id":"sct_1","driver":{"id":"usr_d","firstName":"Asha","ratingAvg":4.8},'
    '"vehicle":{"type":"CAR","make":"Maruti","model":"Swift","color":"White"},'
    '"origin":{"lat":22.57,"lng":88.36},"originAddress":"Park St",'
    '"destination":{"lat":22.62,"lng":88.43},"destAddress":"Airport",'
    '"departureAt":"2026-06-20T09:30:00.000Z","totalSeats":3,"availableSeats":2,'
    '"pricePerSeat":15000,"notes":"One bag each","preferences":{"ac":true,"gender":"FEMALE"},'
    '"status":"OPEN","createdAt":"2026-06-13T10:00:00.000Z"}';

void main() {
  group('CarpoolApi', () {
    test('create posts the route, departure and price as paise', () async {
      final (dio, adapter) = _dioWith('{"success":true,"data":$_tripJson}');
      final api = CarpoolApi(dio);

      final trip = await api.create(
        origin: const LatLngPoint(lat: 22.57, lng: 88.36),
        originAddress: 'Park St',
        destination: const LatLngPoint(lat: 22.62, lng: 88.43),
        destAddress: 'Airport',
        departureAt: DateTime.utc(2026, 6, 20, 9, 30),
        vehicleId: 'veh_1',
        totalSeats: 3,
        pricePerSeat: 15000,
        notes: 'One bag each',
        preferences: const TripPreferences(
          ac: true,
          gender: GenderPreference.female,
        ),
      );

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/scheduled-trips');
      final sent = adapter.lastRequest?.data as Map;
      expect(sent['origin'], {'lat': 22.57, 'lng': 88.36});
      expect(sent['vehicleId'], 'veh_1');
      expect(sent['pricePerSeat'], 15000);
      expect(sent['departureAt'], '2026-06-20T09:30:00.000Z');
      expect((sent['preferences'] as Map)['gender'], 'FEMALE');

      expect(trip.id, 'sct_1');
      expect(trip.status, ScheduledTripStatus.open);
      expect(trip.bookedSeats, 1);
      expect(trip.pricePerSeat, 15000);
      expect(trip.vehicle.display, 'Maruti Swift · White');
    });

    test('mine forwards the status filter and pagination', () async {
      final (dio, adapter) = _dioWith('{"success":true,"data":[$_tripJson]}');
      final api = CarpoolApi(dio);

      final trips = await api.mine(
        page: 2,
        pageSize: 10,
        status: ScheduledTripStatus.inProgress,
      );

      expect(adapter.lastRequest?.path, '/scheduled-trips/me');
      expect(adapter.lastRequest?.uri.queryParameters['status'], 'IN_PROGRESS');
      expect(adapter.lastRequest?.uri.queryParameters['page'], '2');
      expect(trips, hasLength(1));
    });

    test('markNoShow posts to the booking path', () async {
      final (dio, adapter) = _dioWith(
        '{"success":true,"data":{"id":"bkg_1","scheduledTripId":"sct_1",'
        '"seats":1,"amount":15000,"status":"NO_SHOW","paymentStatus":"REFUNDED",'
        '"createdAt":"2026-06-13T10:00:00.000Z"}}',
      );
      final api = CarpoolApi(dio);

      final booking = await api.markNoShow('bkg_1');

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/bookings/bkg_1/no-show');
      expect(booking.status, BookingStatus.noShow);
      expect(booking.paymentStatus, BookingPaymentStatus.refunded);
    });
  });

  group('ChatApi', () {
    test('send posts the recipient and message body', () async {
      final (dio, adapter) = _dioWith(
        '{"success":true,"data":{"id":"msg_1","fromUserId":"usr_d",'
        '"toUserId":"usr_r","type":"USER","body":"On my way","mine":true,'
        '"createdAt":"2026-06-13T10:05:00.000Z"}}',
      );
      final api = ChatApi(dio);

      final msg = await api.send(toUserId: 'usr_r', message: 'On my way');

      expect(adapter.lastRequest?.path, '/chats/messages');
      final sent = adapter.lastRequest?.data as Map;
      expect(sent['toUserId'], 'usr_r');
      expect(sent['message'], 'On my way');
      expect(sent.containsKey('scheduledTripId'), isFalse);
      expect(msg.mine, isTrue);
      expect(msg.otherUserId, 'usr_r');
    });

    test('markRead posts to the thread read path', () async {
      final (dio, adapter) = _dioWith('{"success":true,"data":null}');
      final api = ChatApi(dio);

      await api.markRead('usr_r');

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/chats/threads/usr_r/read');
    });
  });
}
