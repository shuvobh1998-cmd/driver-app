import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_envelope.dart';
import 'models/earnings_enums.dart';
import 'models/earnings_summary.dart';
import 'models/invoice.dart';
import 'models/ledger_entry.dart';
import 'models/payment.dart';
import 'models/payout.dart';
import 'models/payout_method.dart';
import 'models/wallet.dart';

/// Transport over the driver earnings, wallet and payout endpoints (D5). Money
/// in every payload is integer **paise**. State-changing POSTs (cash-collected,
/// payout request) carry an `Idempotency-Key` automatically via the interceptor,
/// so a retried tap settles exactly once.
class EarningsApi {
  EarningsApi(this._dio);

  final Dio _dio;

  /// Wallet balance + lifetime totals.
  Future<Wallet> wallet() async {
    final res = await _dio.get<dynamic>('/drivers/me/wallet');
    return res.unwrap(Wallet.fromJson);
  }

  /// One page of the wallet ledger, newest first.
  Future<List<LedgerEntry>> ledger({int page = 1, int pageSize = 20}) async {
    final res = await _dio.get<dynamic>(
      '/drivers/me/wallet/ledger',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return res.unwrapList(LedgerEntry.fromJson);
  }

  /// Earnings for one window (today / this-week / this-month).
  Future<EarningsSummary> earnings(EarningsPeriod period) async {
    final res = await _dio.get<dynamic>('/drivers/me/earnings/${period.path}');
    return res.unwrap(EarningsSummary.fromJson);
  }

  /// The saved payout method, or null when none is set yet.
  Future<PayoutMethod?> payoutMethod() async {
    try {
      final res = await _dio.get<dynamic>('/drivers/me/payout-method');
      final body = res.data;
      final data = body is Map ? body['data'] : body;
      if (data == null) return null;
      return res.unwrap(PayoutMethod.fromJson);
    } on DioException catch (e) {
      // No method set surfaces as a 404 on some deployments — treat as null.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Saves (creates or replaces) the payout method.
  Future<PayoutMethod> setPayoutMethod(UpdatePayoutMethod body) async {
    final res = await _dio.put<dynamic>(
      '/drivers/me/payout-method',
      data: body.toJson(),
    );
    return res.unwrap(PayoutMethod.fromJson);
  }

  /// One page of withdrawal requests, newest first.
  Future<List<Payout>> payouts({int page = 1, int pageSize = 20}) async {
    final res = await _dio.get<dynamic>(
      '/drivers/me/payouts',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return res.unwrapList(Payout.fromJson);
  }

  /// A single payout by id.
  Future<Payout> payout(String id) async {
    final res = await _dio.get<dynamic>('/drivers/me/payouts/$id');
    return res.unwrap(Payout.fromJson);
  }

  /// Requests a withdrawal of [amount] paise. Errors: `INSUFFICIENT_BALANCE`,
  /// `PAYOUT_METHOD_REQUIRED`.
  Future<Payout> requestPayout({required int amount, String? notes}) async {
    final res = await _dio.post<dynamic>(
      '/drivers/me/payouts/request',
      data: {
        'amount': amount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return res.unwrap(Payout.fromJson);
  }

  /// Closes a finished CASH trip: debits commission + GST from the wallet. The
  /// idempotency key makes a repeated tap safe (`ALREADY_*` guarded server-side).
  Future<Payment> cashCollected(String tripId) async {
    final res = await _dio.post<dynamic>(
      '/trips/$tripId/payment/cash-collected',
      data: const <String, dynamic>{},
    );
    return res.unwrap(Payment.fromJson);
  }

  /// The trip's tax invoice as structured JSON line items.
  Future<Invoice> invoice(String tripId) async {
    final res = await _dio.get<dynamic>('/trips/$tripId/invoice');
    return res.unwrap(Invoice.fromJson);
  }

  /// Downloads the invoice PDF to a temp file and returns its path, ready to
  /// hand to the OS viewer. Auth is attached by the interceptor stack.
  Future<String> downloadInvoicePdf(String tripId) async {
    final res = await _dio.get<List<int>>(
      '/trips/$tripId/invoice.pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'invoice_$tripId.pdf'));
    await file.writeAsBytes(res.data ?? const <int>[], flush: true);
    return file.path;
  }
}
