import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/driver_home/presentation/placeholder_home_screen.dart';

/// Named route paths. Centralized so deep links (FCM) and guards reference one
/// source of truth as screens are added per sprint.
abstract final class Routes {
  static const home = '/';
  // Filled in per sprint: splash, phone, otp, login, onboarding, trip, …
}

/// The app's [GoRouter]. Sprint 0 ships a single placeholder route; the auth
/// guard hook is in place (currently a no-op) so D1 only fills in the redirect
/// logic, not the plumbing.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      // TODO(D1): if unauthenticated and not on an auth route, send to login;
      // if authenticated and on an auth route, send home. Watch AuthController.
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const PlaceholderHomeScreen(),
      ),
    ],
  );
});
