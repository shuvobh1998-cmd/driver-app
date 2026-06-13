import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_flow_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/driver_home/presentation/screens/driver_home_screen.dart';
import '../../features/earnings/presentation/screens/earnings_dashboard_screen.dart';
import '../../features/earnings/presentation/screens/invoice_screen.dart';
import '../../features/earnings/presentation/screens/payout_detail_screen.dart';
import '../../features/earnings/presentation/screens/payout_method_screen.dart';
import '../../features/earnings/presentation/screens/payouts_screen.dart';
import '../../features/earnings/presentation/screens/request_payout_screen.dart';
import '../../features/earnings/presentation/screens/wallet_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/approval_status_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/become_driver_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/kyc_documents_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/onboarding_checklist_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/vehicles_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/sessions_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/trips/presentation/screens/active_trip_screen.dart';
import '../../features/trips/presentation/screens/incoming_offer_screen.dart';
import '../../features/trips/presentation/screens/rate_rider_screen.dart';
import '../../features/trips/presentation/screens/trip_detail_screen.dart';
import '../../features/trips/presentation/screens/trip_history_screen.dart';
import '../../features/trips/presentation/screens/trip_summary_screen.dart';

/// Named route paths. Centralized so deep links (FCM) and the auth guard
/// reference one source of truth as screens are added per sprint.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot';
  static const home = '/';
  static const profile = '/profile';
  static const settings = '/settings';
  static const sessions = '/settings/sessions';
  static const becomeDriver = '/become-driver';
  static const onboarding = '/onboarding';
  static const kycDocuments = '/onboarding/documents';
  static const vehicles = '/onboarding/vehicles';
  static const approvalStatus = '/onboarding/status';
  static const tripOffer = '/trip/offer';
  static const activeTrip = '/trip/active';
  static const tripHistory = '/trips';
  static const earnings = '/earnings';
  static const wallet = '/earnings/wallet';
  static const payouts = '/earnings/payouts';
  static const payoutMethod = '/earnings/payout-method';
  static const requestPayout = '/earnings/withdraw';

  /// Routes a signed-out user is allowed to sit on.
  static bool isAuthRoute(String location) =>
      location.startsWith(login) ||
      location.startsWith(signup) ||
      location.startsWith(forgot);
}

/// The app's [GoRouter] with the auth guard. Built once; auth-state changes
/// drive [GoRouter.refresh] via [refreshListenable] so the redirect re-runs
/// without rebuilding the router (and losing the navigation stack).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final onSplash = loc == Routes.splash;

      // While the session is still being restored, hold on the splash.
      if (!auth.isResolved) return onSplash ? null : Routes.splash;

      final loggedIn = auth.isAuthenticated;
      if (onSplash) return loggedIn ? Routes.home : Routes.login;
      if (!loggedIn && !Routes.isAuthRoute(loc)) return Routes.login;
      if (loggedIn && Routes.isAuthRoute(loc)) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => const SignupFlowScreen(),
      ),
      GoRoute(
        path: Routes.forgot,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.sessions,
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: Routes.becomeDriver,
        builder: (context, state) => const BecomeDriverScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingChecklistScreen(),
      ),
      GoRoute(
        path: Routes.kycDocuments,
        builder: (context, state) => const KycDocumentsScreen(),
      ),
      GoRoute(
        path: Routes.vehicles,
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: Routes.approvalStatus,
        builder: (context, state) => const ApprovalStatusScreen(),
      ),
      GoRoute(
        path: Routes.tripOffer,
        builder: (context, state) => const IncomingOfferScreen(),
      ),
      GoRoute(
        path: Routes.activeTrip,
        builder: (context, state) => const ActiveTripScreen(),
      ),
      GoRoute(
        path: Routes.tripHistory,
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: Routes.earnings,
        builder: (context, state) => const EarningsDashboardScreen(),
      ),
      GoRoute(
        path: Routes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: Routes.payouts,
        builder: (context, state) => const PayoutsScreen(),
      ),
      GoRoute(
        path: Routes.payoutMethod,
        builder: (context, state) => const PayoutMethodScreen(),
      ),
      GoRoute(
        path: Routes.requestPayout,
        builder: (context, state) => const RequestPayoutScreen(),
      ),
      GoRoute(
        path: '/payouts/:id',
        builder: (context, state) =>
            PayoutDetailScreen(payoutId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id/invoice',
        builder: (context, state) =>
            InvoiceScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) =>
            TripDetailScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/summary',
        builder: (context, state) =>
            TripSummaryScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/rate',
        builder: (context, state) =>
            RateRiderScreen(tripId: state.pathParameters['id']!),
      ),
    ],
  );
});
