import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's [SharedPreferences] handle. Overridden in `bootstrap` with the
/// instance loaded once at startup so the rest of the app — including the
/// router's synchronous redirect — can read flags without awaiting.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// Whether the first-launch intro tour has been completed. Backed by
/// [SharedPreferences] so the flag survives restarts; exposed as state so the
/// router redirect can branch on it and `markSeen` can flip it live.
class OnboardingSeen extends Notifier<bool> {
  static const _key = 'onboarding_seen_v1';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> markSeen() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
    state = true;
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeen, bool>(
  OnboardingSeen.new,
);
