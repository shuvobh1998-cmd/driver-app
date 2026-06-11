import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/remote_config_providers.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/auth_controller.dart';

/// First screen on launch. Checks the force-update gate, then restores any
/// persisted session. The router holds here (auth stays `unknown`) until
/// restore resolves, then redirects to home or login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // Force-update is best-effort: a config failure must not strand the app,
    // so we fall through to session restore if the check can't complete.
    try {
      final config = await ref.read(appRemoteConfigProvider.future);
      if (!mounted) return;
      if (isUpdateRequired(config)) {
        setState(() => _updateRequired = true);
        return;
      }
    } catch (_) {
      // ignore — proceed to restore.
    }
    await ref.read(authControllerProvider.notifier).restore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: _updateRequired
              ? _UpdateRequiredView(
                  onRetry: () {
                    setState(() => _updateRequired = false);
                    ref.invalidate(appRemoteConfigProvider);
                    _init();
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_taxi,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const LoadingState(message: 'Getting things ready…'),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _UpdateRequiredView extends StatelessWidget {
  const _UpdateRequiredView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.system_update,
      title: 'Update required',
      message:
          'A newer version of the Driver app is needed to continue. Please '
          'update from the Play Store, then reopen the app.',
      actionLabel: 'I\'ve updated',
      onAction: onRetry,
    );
  }
}
