import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import '../../data/models/auth_user.dart';

/// Where the session stands. `unknown` is the boot state while we try to
/// restore a session; the router shows the splash until it resolves.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user});

  const AuthState.unknown() : status = AuthStatus.unknown, user = null;
  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      user = null;
  const AuthState.authenticated(AuthUser this.user)
    : status = AuthStatus.authenticated;

  final AuthStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;
}

/// Single source of truth for the session. UI calls the mutating methods
/// (which surface [AppFailure] on error) and the router watches [state].
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // A failed token refresh anywhere in the app drops us back to login.
    final sub = ref
        .watch(authTokenServiceProvider)
        .onForcedSignOut
        .listen((_) => state = const AuthState.unauthenticated());
    ref.onDispose(sub.cancel);
    return const AuthState.unknown();
  }

  /// Restores a persisted session on launch. Always resolves [state] away from
  /// `unknown`, so the splash can route.
  Future<void> restore() async {
    try {
      final user = await _repo.restoreSession();
      state = user == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(user);
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String phone, required String password}) async {
    final user = await _repo.login(phone: phone, password: password);
    state = AuthState.authenticated(user);
  }

  Future<void> completeSignup({
    required String signupToken,
    required String firstName,
    required String password,
    required String passwordConfirm,
    String? lastName,
    String? email,
    String? gender,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final user = await _repo.signupComplete(
      signupToken: signupToken,
      firstName: firstName,
      password: password,
      passwordConfirm: passwordConfirm,
      lastName: lastName,
      email: email,
      gender: gender,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );
    state = AuthState.authenticated(user);
  }

  Future<void> loginWithFirebaseOtp(String firebaseIdToken) async {
    final user = await _repo.otpVerify(firebaseIdToken);
    state = AuthState.authenticated(user);
  }

  Future<void> resetPasswordWithOtp({
    required String resetTicket,
    required String firebaseIdToken,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final user = await _repo.forgotReset(
      resetTicket: resetTicket,
      firebaseIdToken: firebaseIdToken,
      newPassword: newPassword,
      newPasswordConfirm: newPasswordConfirm,
    );
    state = AuthState.authenticated(user);
  }

  /// Replaces the cached user after a profile edit, keeping the session.
  void updateUser(AuthUser user) {
    if (state.isAuthenticated) state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Convenience: the signed-in user, or null.
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);
