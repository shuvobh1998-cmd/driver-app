import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/notifications_providers.dart';

/// Renders a legal document (terms, privacy, driver agreement) by slug. The body
/// is Markdown source shown as plain selectable text (no Markdown dependency).
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(legalProvider(slug));
    return AppScaffold(
      title: 'Legal',
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(legalProvider(slug)),
        ),
        data: (doc) => ListView(
          children: [
            Text(
              doc.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Updated ${doc.updatedAt.toFriendly()}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(doc.body),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
