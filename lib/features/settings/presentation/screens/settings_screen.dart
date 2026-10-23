import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/data_export.dart';
import '../../data/user_providers.dart';
import '../controllers/locale_controller.dart';

/// The settings hub: profile, language, devices, session actions, the personal
/// data export and the account-deletion request.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _languageNames = {
    'en': 'English',
    'bn': 'বাংলা',
    'hi': 'हिन्दी',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final currentLang = locale?.languageCode;
    final isDriver = ref.watch(currentUserProvider)?.isDriver ?? false;

    return AppScaffold(
      title: 'Settings',
      padded: false,
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            subtitle: const Text('Name, email, photo, emergency contact'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.profile),
          ),
          ListTile(
            leading: const Icon(Icons.local_taxi),
            title: Text(isDriver ? 'Driver onboarding' : 'Become a driver'),
            subtitle: Text(
              isDriver
                  ? 'Documents, vehicle and approval status'
                  : 'Submit your documents and start earning',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              isDriver ? Routes.onboarding : Routes.becomeDriver,
            ),
          ),
          if (isDriver)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Earnings & wallet'),
              subtitle: const Text('Earnings, wallet ledger and payouts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.earnings),
            ),
          if (isDriver)
            ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Carpool trips'),
              subtitle: const Text('Post scheduled trips and chat with riders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.carpool),
            ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Devices & sessions'),
            subtitle: const Text('See where you are signed in'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.sessions),
          ),
          const Divider(height: 1),
          const _SectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(
              currentLang == null
                  ? 'Follow system'
                  : _languageNames[currentLang] ?? currentLang,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref, currentLang),
          ),
          const Divider(height: 1),
          const _SectionHeader('Help & support'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Trip, payment and safety alerts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support tickets'),
            subtitle: const Text('Get help or report a lost item'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.support),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help center'),
            subtitle: const Text('FAQ, terms and privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.help),
          ),
          const Divider(height: 1),
          const _SectionHeader('Session'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => _logout(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: const Text('Log out all other devices'),
            onTap: () => _logoutOthers(context, ref),
          ),
          const Divider(height: 1),
          const _SectionHeader('Your data'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download my data'),
            subtitle: const Text('A copy of everything we hold about you'),
            onTap: () => _exportData(context, ref),
          ),
          const Divider(height: 1),
          const _SectionHeader('Danger zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: const Text('Request account deletion'),
            subtitle: const Text('Schedules your account for removal'),
            onTap: () => _requestDeletion(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Cancel deletion request'),
            onTap: () => _cancelDeletion(context, ref),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final choice = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) {
        Widget tile(String? code, String label) => ListTile(
          title: Text(label),
          trailing: current == code ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(ctx, code ?? '__system__'),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(null, 'Follow system'),
              for (final entry in _languageNames.entries)
                tile(entry.key, entry.value),
            ],
          ),
        );
      },
    );
    if (choice == null) return; // dismissed
    final code = choice == '__system__' ? null : choice;
    await ref.read(localeControllerProvider.notifier).set(code);
    // Mirror to backend preferences (best-effort; ignore failures).
    if (code != null) {
      try {
        await ref.read(userApiProvider).updatePreferences({'language': code});
      } catch (_) {}
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).logout();
      // Router redirects to login.
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  Future<void> _logoutOthers(BuildContext context, WidgetRef ref) async {
    try {
      final revoked = await ref.read(authRepositoryProvider).logoutAllOthers();
      ref.invalidate(userSessionsProvider);
      if (context.mounted) {
        context.showInfoSnack('Signed out $revoked other device(s).');
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    context.showInfoSnack('Preparing your data…');
    final DataExport export;
    try {
      export = await ref.read(userApiProvider).requestDataExport();
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final details = [
      ?export.sizeLabel,
      if (export.expiresAt != null)
        'link valid until ${export.expiresAt!.toFriendly()}',
    ].join(' · ');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your data is ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open this link in a browser to download a JSON copy of your '
              'data. We\'ve also sent it to your notifications.',
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(details, style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              export.url,
              style: Theme.of(ctx).textTheme.bodySmall,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: export.url));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.showInfoSnack('Link copied.');
            },
            child: const Text('Copy link'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Request account deletion?',
      message:
          'Your account will be scheduled for deletion. You can cancel before '
          'the scheduled date.',
      confirmLabel: 'Request deletion',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final res = await ref.read(userApiProvider).requestAccountDeletion();
      if (context.mounted) {
        context.showInfoSnack(
          res.scheduledAt == null
              ? 'Deletion requested.'
              : 'Scheduled for ${res.scheduledAt!.toLocal()}.',
        );
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  Future<void> _cancelDeletion(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(userApiProvider).cancelAccountDeletion();
      if (context.mounted) context.showInfoSnack('Deletion request cancelled.');
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: danger
                ? TextButton.styleFrom(foregroundColor: AppColors.danger)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
