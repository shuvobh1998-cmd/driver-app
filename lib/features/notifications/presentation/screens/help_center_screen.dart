import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/content_item.dart';
import '../../data/notifications_providers.dart';

/// The help center: FAQ entries grouped by category (expandable), plus links to
/// the legal documents and a shortcut to contact support.
class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqAsync = ref.watch(faqProvider);

    return AppScaffold(
      title: 'Help center',
      padded: false,
      body: faqAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(faqProvider),
        ),
        data: (faqs) {
          final grouped = _groupByCategory(faqs);
          return ListView(
            children: [
              if (faqs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: EmptyState(
                    icon: Icons.help_outline,
                    title: 'No FAQs yet',
                    message: 'Check back soon, or contact support.',
                  ),
                ),
              for (final entry in grouped.entries) ...[
                _SectionHeader(entry.key),
                for (final item in entry.value) _FaqTile(item: item),
              ],
              const Divider(height: 1),
              const _SectionHeader('Legal'),
              const _LegalTile(slug: 'terms', title: 'Terms of service'),
              const _LegalTile(slug: 'privacy', title: 'Privacy policy'),
              const _LegalTile(
                slug: 'driver-agreement',
                title: 'Driver agreement',
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Contact support'),
                subtitle: const Text('Open a ticket with our team'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/support'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<ContentItem>> _groupByCategory(List<ContentItem> faqs) {
    final map = <String, List<ContentItem>>{};
    for (final f in faqs) {
      map.putIfAbsent(f.category ?? 'General', () => []).add(f);
    }
    return map;
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(item.title),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(item.body)],
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.slug, required this.title});

  final String slug;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/legal/$slug'),
    );
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
