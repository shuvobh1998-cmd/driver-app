import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_flow_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/driver_home/presentation/placeholder_home_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/approval_status_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/become_driver_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/kyc_documents_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/onboarding_checklist_screen.dart';
import '../../features/onboarding_kyc/presentation/screens/vehicles_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/sessions_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

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
        builder: (context, state) => const PlaceholderHomeScreen(),
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
    ],
  );
});
