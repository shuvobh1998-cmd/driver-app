import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/support.dart';
import '../../data/notifications_providers.dart';

/// Opens a support ticket, or reports a lost item when [lostItem] is true (which
/// uses the dedicated endpoint and hides the category picker). Pops `true` on
/// success so the list refreshes.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key, this.lostItem = false, this.tripId});

  final bool lostItem;
  final String? tripId;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  TicketCategory _category = TicketCategory.other;
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final api = ref.read(supportApiProvider);
      if (widget.lostItem) {
        await api.reportLostItem(
          subject: _subject.text.trim(),
          description: _description.text.trim(),
          tripId: widget.tripId,
        );
      } else {
        await api.createTicket(
          category: _category,
          subject: _subject.text.trim(),
          description: _description.text.trim(),
          tripId: widget.tripId,
        );
      }
      if (mounted) {
        context.showInfoSnack(
          widget.lostItem ? 'Lost-item report sent.' : 'Ticket opened.',
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.lostItem ? 'Report a lost item' : 'New ticket',
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            if (!widget.lostItem) ...[
              DropdownButtonFormField<TicketCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  for (final c in TicketCategory.selectable)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) =>
                    setState(() => _category = c ?? TicketCategory.other),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              controller: _subject,
              label: widget.lostItem ? 'What did you lose?' : 'Subject',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _description,
              label: 'Describe the issue',
              hint: widget.lostItem
                  ? 'Where you sat, what it looks like, the trip…'
                  : 'Give us the details',
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Add a little more detail'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: widget.lostItem ? 'Send report' : 'Open ticket',
              icon: Icons.send,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
