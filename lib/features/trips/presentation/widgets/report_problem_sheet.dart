import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/trip_enums.dart';
import '../../data/trips_providers.dart';

/// Bottom sheet to file a problem report against [tripId]. Returns true once a
/// report is filed so the caller can confirm it.
Future<bool?> showReportProblemSheet(BuildContext context, String tripId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ReportProblemSheet(tripId: tripId),
    ),
  );
}

class _ReportProblemSheet extends ConsumerStatefulWidget {
  const _ReportProblemSheet({required this.tripId});
  final String tripId;

  @override
  ConsumerState<_ReportProblemSheet> createState() =>
      _ReportProblemSheetState();
}

class _ReportProblemSheetState extends ConsumerState<_ReportProblemSheet> {
  ReportCategory _category = ReportCategory.safety;
  final _description = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Add a short description.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(tripsApiProvider)
          .report(widget.tripId, category: _category, description: description);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showErrorSnack(e);
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
            Text('Report a problem', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ReportCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ReportCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: _submitting
                  ? null
                  : (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'What happened?',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Submit report',
              icon: Icons.flag,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
