import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/network_providers.dart';
import '../design_system/design_system.dart';

/// Covers the whole app with [UpdateRequiredView] once any call has answered
/// `426 FORCE_UPDATE_REQUIRED`. The navigator stays mounted underneath, so
/// dismissing returns the driver to where they were (and the next 426 raises
/// the screen again).
class ForceUpdateGate extends ConsumerWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateRequired = ref.watch(forceUpdateRequiredProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (updateRequired)
          Scaffold(
            body: SafeArea(
              child: Padding(
                padding: AppSpacing.screen,
                child: UpdateRequiredView(
                  onRetry: () =>
                      ref.read(forceUpdateRequiredProvider.notifier).dismiss(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The blocking "update the app" message, shared by the splash's config check
/// and [ForceUpdateGate].
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({super.key, required this.onRetry});

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
