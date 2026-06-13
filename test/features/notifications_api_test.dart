import 'package:dio/dio.dart';
import 'package:driver_app/features/notifications/data/models/support.dart';
import 'package:driver_app/features/notifications/data/notifications_api.dart';
import 'package:driver_app/features/notifications/data/safety_api.dart';
import 'package:driver_app/features/notifications/data/support_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the last request and replies with a canned envelope.
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

void main() {
  group('NotificationsApi', () {
    test('unreadCount reads a bare int payload', () async {
      final (dio, _) = _dioWith('{"success":true,"data":7}');
      expect(await NotificationsApi(dio).unreadCount(), 7);
    });

    test('unreadCount reads a {count} object payload', () async {
      final (dio, _) = _dioWith('{"success":true,"data":{"count":3}}');
      expect(await NotificationsApi(dio).unreadCount(), 3);
    });

    test('registerDeviceToken posts token + platform', () async {
      final (dio, adapter) = _dioWith('{"success":true,"data":null}');
      await NotificationsApi(
        dio,
      ).registerDeviceToken(fcmToken: 'tok_1', platform: 'ANDROID');
      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/users/me/device-tokens');
      final sent = adapter.lastRequest?.data as Map;
      expect(sent['fcmToken'], 'tok_1');
      expect(sent['platform'], 'ANDROID');
      expect(sent.containsKey('deviceInfo'), isFalse);
    });

    test('unregisterDeviceToken sends the token in the DELETE body', () async {
      final (dio, adapter) = _dioWith('{"success":true,"data":null}');
      await NotificationsApi(dio).unregisterDeviceToken('tok_1');
      expect(adapter.lastRequest?.method, 'DELETE');
      expect((adapter.lastRequest?.data as Map)['fcmToken'], 'tok_1');
    });
  });

  group('SafetyApi', () {
    test('raiseSos posts the note and omits null coordinates', () async {
      final (dio, adapter) = _dioWith(
        '{"success":true,"data":{"id":"sos_1","contactsNotified":2,'
        '"createdAt":"2026-06-13T10:00:00.000Z"}}',
      );
      final event = await SafetyApi(dio).raiseSos('trp_1', note: 'help');
      expect(adapter.lastRequest?.path, '/trips/trp_1/sos');
      final sent = adapter.lastRequest?.data as Map;
      expect(sent['note'], 'help');
      expect(sent.containsKey('lat'), isFalse);
      expect(event.contactsNotified, 2);
    });

    test('share posts recipient phones and expiry', () async {
      final (dio, adapter) = _dioWith(
        '{"success":true,"data":{"id":"shr_1","url":"https://t.co/x",'
        '"recipientsNotified":1,"expiresAt":null,'
        '"createdAt":"2026-06-13T10:00:00.000Z"}}',
      );
      final share = await SafetyApi(dio).share(
        'trp_1',
        recipientPhones: const ['+919876543210'],
        expiresInHours: 24,
      );
      final sent = adapter.lastRequest?.data as Map;
      expect(sent['recipientPhones'], ['+919876543210']);
      expect(sent['expiresInHours'], 24);
      expect(share.url, 'https://t.co/x');
    });
  });

  group('SupportApi', () {
    test('createTicket sends the wire category', () async {
      final (dio, adapter) = _dioWith(
        '{"success":true,"data":{"id":"tkt_1","category":"PAYMENT_ISSUE",'
        '"subject":"Fare","description":"Wrong fare","status":"OPEN",'
        '"tripId":null,"messages":[],"createdAt":"2026-06-13T10:00:00.000Z",'
        '"updatedAt":"2026-06-13T10:00:00.000Z"}}',
      );
      final ticket = await SupportApi(dio).createTicket(
        category: TicketCategory.paymentIssue,
        subject: 'Fare',
        description: 'Wrong fare',
      );
      final sent = adapter.lastRequest?.data as Map;
      expect(adapter.lastRequest?.path, '/support/tickets');
      expect(sent['category'], 'PAYMENT_ISSUE');
      expect(ticket.status, TicketStatus.open);
      expect(ticket.category, TicketCategory.paymentIssue);
    });

    test('reportLostItem hits the lost-item endpoint', () async {
      final (dio, adapter) = _dioWith(
        '{"success":true,"data":{"id":"tkt_2","category":"LOST_ITEM",'
        '"subject":"Phone","description":"Black phone","status":"OPEN",'
        '"tripId":"trp_1","messages":[],"createdAt":"2026-06-13T10:00:00.000Z",'
        '"updatedAt":"2026-06-13T10:00:00.000Z"}}',
      );
      final ticket = await SupportApi(dio).reportLostItem(
        subject: 'Phone',
        description: 'Black phone',
        tripId: 'trp_1',
      );
      expect(adapter.lastRequest?.path, '/support/lost-item');
      expect(ticket.category, TicketCategory.lostItem);
    });
  });
}
