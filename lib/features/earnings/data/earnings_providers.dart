import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import 'earnings_api.dart';
import 'models/earnings_enums.dart';
import 'models/earnings_summary.dart';
import 'models/invoice.dart';
import 'models/payout.dart';
import 'models/payout_method.dart';
import 'models/wallet.dart';

/// Transport over the earnings, wallet and payout endpoints.
final earningsApiProvider = Provider<EarningsApi>(
  (ref) => EarningsApi(ref.watch(apiClientProvider).dio),
);

/// Wallet snapshot (balance + lifetime totals). Invalidate after a payout or a
/// cash-collected close to refresh the balance.
final walletProvider = FutureProvider<Wallet>(
  (ref) => ref.watch(earningsApiProvider).wallet(),
);

/// Earnings for one window. Cached per [EarningsPeriod] by Riverpod.
final earningsProvider = FutureProvider.family<EarningsSummary, EarningsPeriod>(
  (ref, period) => ref.watch(earningsApiProvider).earnings(period),
);

/// The saved payout method, or null when none is set yet.
final payoutMethodProvider = FutureProvider<PayoutMethod?>(
  (ref) => ref.watch(earningsApiProvider).payoutMethod(),
);

/// A single payout by id (status detail). Cached per id; invalidate to refresh
/// a pending one.
final payoutProvider = FutureProvider.family<Payout, String>(
  (ref, id) => ref.watch(earningsApiProvider).payout(id),
);

/// A trip's tax invoice (JSON line items). Cached per trip id.
final invoiceProvider = FutureProvider.family<Invoice, String>(
  (ref, tripId) => ref.watch(earningsApiProvider).invoice(tripId),
);
