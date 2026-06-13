import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/notifications_providers.dart';

/// Shows the in-trip SOS confirm sheet. The driver must press and hold to
/// confirm (avoids an accidental panic), optionally adding a note. On success it
/// raises the SOS for [tripId] and reports how many contacts were alerted.
Future<void> showSosSheet(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SosSheet(tripId: tripId),
    ),
  );
}

class _SosSheet extends ConsumerStatefulWidget {
  const _SosSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends ConsumerState<_SosSheet> {
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _trigger() async {
    setState(() => _sending = true);
    try {
      final event = await ref
          .read(safetyApiProvider)
          .raiseSos(
            widget.tripId,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        context.showInfoSnack(
          'SOS sent — ${event.contactsNotified} contact(s) alerted.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        context.showErrorSnack(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emergency, color: AppColors.danger, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Emergency SOS',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This alerts your emergency contacts and the safety team with your '
              'live location. Press and hold to confirm.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _note,
              label: 'Add a note (optional)',
              hint: 'What is happening?',
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onLongPress: _sending ? null : _trigger,
              child: FilledButton(
                onPressed: _sending ? null : () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
                ),
                child: _sending
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'HOLD TO SEND SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
