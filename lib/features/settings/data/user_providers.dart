import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/data/models/auth_session.dart';
import '../../auth/data/models/user_profile.dart';
import 'models/user_preferences.dart';
import 'user_api.dart';

final userApiProvider = Provider<UserApi>(
  (ref) => UserApi(ref.watch(apiClientProvider).dio),
);

/// The full profile (`/users/me/profile`). Invalidate to refetch after an edit.
final userProfileProvider = FutureProvider<UserProfile>(
  (ref) => ref.watch(userApiProvider).getProfile(),
);

final userPreferencesProvider = FutureProvider<UserPreferences>(
  (ref) => ref.watch(userApiProvider).getPreferences(),
);

final userSessionsProvider = FutureProvider<List<AuthSession>>(
  (ref) => ref.watch(userApiProvider).getSessions(),
);
