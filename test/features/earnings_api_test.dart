import 'package:dio/dio.dart';
import 'package:driver_app/features/earnings/data/earnings_api.dart';
import 'package:driver_app/features/earnings/data/models/earnings_enums.dart';
import 'package:driver_app/features/earnings/data/models/payout_method.dart';
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

(EarningsApi, _StubAdapter) _apiWith(String body, {int statusCode = 200}) {
  final adapter = _StubAdapter(body, statusCode: statusCode);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter
    // Don't throw on the 404 we use to signal "no payout method".
    ..options.validateStatus = (_) => true;
  return (EarningsApi(dio), adapter);
}

void main() {
  test('wallet parses paise fields', () async {
    final (api, _) = _apiWith(
      '{"success":true,"data":{"balance":10667,"totalEarned":53400,'
      '"totalPaidOut":40000,"currency":"INR"}}',
    );

    final wallet = await api.wallet();

    expect(wallet.balance, 10667);
    expect(wallet.totalEarned, 53400);
    expect(wallet.totalPaidOut, 40000);
    expect(wallet.currency, 'INR');
  });

  test('earnings maps the period to its path', () async {
    final (api, adapter) = _apiWith(
      '{"success":true,"data":{"period":"this-week","from":"2026-06-01T00:00:00.000Z",'
      '"to":"2026-06-07T23:59:59.999Z","tripsCount":12,"grossFare":87850,'
      '"netEarning":74672,"currency":"INR"}}',
    );

    final earnings = await api.earnings(EarningsPeriod.thisWeek);

    expect(adapter.lastRequest?.path, '/drivers/me/earnings/this-week');
    expect(earnings.tripsCount, 12);
    expect(earnings.netEarning, 74672);
  });

  test('ledger forwards pagination as query params', () async {
    final (api, adapter) = _apiWith('{"success":true,"data":[]}');

    await api.ledger(page: 3, pageSize: 10);

    expect(adapter.lastRequest?.path, '/drivers/me/wallet/ledger');
    expect(adapter.lastRequest?.queryParameters['page'], 3);
    expect(adapter.lastRequest?.queryParameters['pageSize'], 10);
  });

  test('payoutMethod returns null on a 404 (none set)', () async {
    final (api, _) = _apiWith(
      '{"success":false,"error":{"code":"NOT_FOUND","message":"none"}}',
      statusCode: 404,
    );
    expect(await api.payoutMethod(), isNull);
  });

  test('setPayoutMethod sends only the UPI fields', () async {
    final (api, adapter) = _apiWith(
      '{"success":true,"data":{"methodType":"UPI","upiId":"driver@okaxis"}}',
    );

    await api.setPayoutMethod(
      const UpdatePayoutMethod.upi(upiId: 'driver@okaxis'),
    );

    expect(adapter.lastRequest?.method, 'PUT');
    final data = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(data['methodType'], 'UPI');
    expect(data['upiId'], 'driver@okaxis');
    // includeIfNull:false drops the bank-only fields.
    expect(data.containsKey('accountNumber'), isFalse);
  });

  test('requestPayout posts the amount and omits an empty note', () async {
    final (api, adapter) = _apiWith(
      '{"success":true,"data":{"id":"pyt_1","amount":50000,"methodType":"UPI",'
      '"status":"PENDING","requestedAt":"2026-06-04T10:00:00.000Z"}}',
    );

    final payout = await api.requestPayout(amount: 50000);

    expect(adapter.lastRequest?.path, '/drivers/me/payouts/request');
    final data = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(data['amount'], 50000);
    expect(data.containsKey('notes'), isFalse);
    expect(payout.status, PayoutStatus.pending);
  });

  test('cashCollected posts to the trip payment path', () async {
    final (api, adapter) = _apiWith(
      '{"success":true,"data":{"id":"pay_1","tripId":"trp_1","method":"CASH",'
      '"amount":12550,"commission":1255,"gst":628,"driverEarning":10667,'
      '"currency":"INR","status":"PAID","createdAt":"2026-06-04T10:04:30.000Z"}}',
    );

    final payment = await api.cashCollected('trp_1');

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/trips/trp_1/payment/cash-collected');
    expect(payment.platformCut, 1255 + 628);
  });
}
