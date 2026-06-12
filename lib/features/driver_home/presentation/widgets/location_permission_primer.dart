import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Explains *why* the app needs "Always" location + a battery exemption before
/// the OS prompt fires, so the driver grants it with context (and we don't burn
/// our one shot at the system dialog on a confused "Deny").
///
/// Returns true if the driver chose to continue to the system prompt.
Future<bool> showLocationPrimer(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _PrimerSheet(),
  );
  return result ?? false;
}

class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.my_location, size: 48, color: AppColors.brand),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Share your location while online',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'To send you nearby trips and show riders where you are, the app '
              'needs your location while you are online — including in the '
              'background.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const _PrimerPoint(
              icon: Icons.location_on,
              text:
                  'Choose "Allow all the time" so trips keep coming when the '
                  'screen is off.',
            ),
            const _PrimerPoint(
              icon: Icons.battery_charging_full,
              text:
                  'Allow it to ignore battery optimisation so Android does not '
                  'pause your location.',
            ),
            const _PrimerPoint(
              icon: Icons.power_settings_new,
              text:
                  'It stops the moment you go offline — nothing is tracked '
                  'when you are off duty.',
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Continue',
              icon: Icons.check,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimerPoint extends StatelessWidget {
  const _PrimerPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
