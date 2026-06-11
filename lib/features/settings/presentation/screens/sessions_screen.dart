import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../auth/data/models/auth_session.dart';
import '../../data/user_providers.dart';

/// Lists active device sessions (`/users/me/sessions`) and lets the driver
/// revoke any device other than the current one.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(userSessionsProvider);
    return AppScaffold(
      title: 'Devices & sessions',
      padded: false,
      body: sessions.when(
        loading: () => const LoadingState(message: 'Loading sessions…'),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(userSessionsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.devices, title: 'No active sessions')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(userSessionsProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _SessionTile(session: list[i], ref: ref),
                ),
              ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.ref});
  final AuthSession session;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final created = session.createdAt;
    return ListTile(
      leading: Icon(session.current ? Icons.smartphone : Icons.devices_other),
      title: Text(session.deviceLabel),
      subtitle: created == null
          ? null
          : Text('Signed in ${created.toFriendly()}'),
      trailing: session.current
          ? const StatusBadge(label: 'This device', tone: StatusTone.success)
          : IconButton(
              tooltip: 'Revoke',
              icon: const Icon(Icons.logout),
              onPressed: () => _revoke(context),
            ),
    );
  }

  Future<void> _revoke(BuildContext context) async {
    try {
      await ref.read(userApiProvider).revokeSession(session.id);
      ref.invalidate(userSessionsProvider);
      if (context.mounted) context.showInfoSnack('Device signed out.');
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }
}
