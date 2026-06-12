import 'package:dio/dio.dart';
import 'package:driver_app/features/driver_home/data/driver_state_api.dart';
import 'package:driver_app/features/driver_home/data/models/driver_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the last request and replies with a canned envelope, so we can
/// assert both the parse and what the client actually sent.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;
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
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(DriverStateApi, _StubAdapter) _apiWith(String body) {
  final adapter = _StubAdapter(body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (DriverStateApi(dio), adapter);
}

const _onlineEnvelope =
    '{"success":true,"data":{'
    '"status":"ONLINE",'
    '"vehicleId":"veh_a1b2c3",'
    '"location":{"lat":22.5726,"lng":88.3639},'
    '"locationUpdatedAt":"2026-06-12T10:00:00.000Z",'
    '"wentOnlineAt":"2026-06-12T09:30:00.000Z"}}';

void main() {
  test('getState maps status, vehicle and nested location', () async {
    final (api, _) = _apiWith(_onlineEnvelope);

    final state = await api.getState();

    expect(state.status, DriverStatus.online);
    expect(state.isOnline, isTrue);
    expect(state.vehicleId, 'veh_a1b2c3');
    expect(state.location?.lat, 22.5726);
    expect(state.location?.lng, 88.3639);
    expect(state.wentOnlineAt, isNotNull);
  });

  test('goOnline posts the vehicleId and parses ONLINE', () async {
    final (api, adapter) = _apiWith(_onlineEnvelope);

    final state = await api.goOnline('veh_a1b2c3');

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/drivers/me/online');
    expect(adapter.lastRequest?.data, {'vehicleId': 'veh_a1b2c3'});
    expect(state.status, DriverStatus.online);
  });

  test('goOffline sends an empty body and parses OFFLINE', () async {
    final (api, adapter) = _apiWith(
      '{"success":true,"data":{"status":"OFFLINE","vehicleId":null,'
      '"location":null,"locationUpdatedAt":null,"wentOnlineAt":null}}',
    );

    final state = await api.goOffline();

    expect(adapter.lastRequest?.data, const <String, dynamic>{});
    expect(state.status, DriverStatus.offline);
    expect(state.isOnline, isFalse);
    expect(state.vehicleId, isNull);
    expect(state.location, isNull);
  });

  test(
    'reportLocation includes optional speed/bearing only when present',
    () async {
      final (api, adapter) = _apiWith(_onlineEnvelope);

      await api.reportLocation(lat: 22.5, lng: 88.3, speed: 8.5);

      final data = adapter.lastRequest?.data as Map<String, dynamic>;
      expect(data['lat'], 22.5);
      expect(data['lng'], 88.3);
      expect(data['speed'], 8.5);
      expect(data.containsKey('bearing'), isFalse);
    },
  );

  test('unknown status falls back to DriverStatus.unknown', () async {
    final (api, _) = _apiWith(
      '{"success":true,"data":{"status":"SOMETHING_NEW"}}',
    );

    final state = await api.getState();

    expect(state.status, DriverStatus.unknown);
    expect(state.isOnline, isFalse);
  });
}
