import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Sprint-0 landing screen. Exists only to prove the shell runs in every
/// flavor with the design system + l10n wired in. The real driver home
/// (online toggle, map, earnings chip) replaces this in D3.
class PlaceholderHomeScreen extends ConsumerWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      title: l10n.appTitle,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Center(child: StatusBadge(label: _flavorLabel(config.flavor))),
        ),
      ],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_taxi, size: 72, color: AppColors.brand),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.placeholderTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              config.apiBaseUrl,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _flavorLabel(AppFlavor flavor) => switch (flavor) {
    AppFlavor.dev => 'DEV',
    AppFlavor.staging => 'STAGING',
    AppFlavor.prod => 'PROD',
  };
}
