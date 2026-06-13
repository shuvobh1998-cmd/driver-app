import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/phone.dart';
import '../../data/models/safety.dart';
import '../../data/notifications_providers.dart';

/// Share a live-tracking link for the active trip with family/friends: create a
/// link (optionally SMS'd to phone numbers), see active links and revoke them.
class ShareTripScreen extends ConsumerStatefulWidget {
  const ShareTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ShareTripScreen> createState() => _ShareTripScreenState();
}

class _ShareTripScreenState extends ConsumerState<ShareTripScreen> {
  final _phones = <String>[];
  final _phoneInput = TextEditingController();
  int _expiresInHours = 24;
  bool _creating = false;

  @override
  void dispose() {
    _phoneInput.dispose();
    super.dispose();
  }

  void _addPhone() {
    final raw = _phoneInput.text.trim();
    if (raw.length != 10) {
      context.showInfoSnack('Enter a valid 10-digit mobile number.');
      return;
    }
    final e164 = Phone.toE164(raw);
    if (!_phones.contains(e164)) {
      setState(() => _phones.add(e164));
    }
    _phoneInput.clear();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await ref
          .read(safetyApiProvider)
          .share(
            widget.tripId,
            recipientPhones: List.of(_phones),
            expiresInHours: _expiresInHours,
          );
      ref.invalidate(tripSharesProvider(widget.tripId));
      if (mounted) {
        setState(_phones.clear);
        context.showInfoSnack('Live tracking link shared.');
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _revoke(TripShare share) async {
    try {
      await ref.read(safetyApiProvider).revoke(widget.tripId, share.id);
      ref.invalidate(tripSharesProvider(widget.tripId));
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharesAsync = ref.watch(tripSharesProvider(widget.tripId));
    return AppScaffold(
      title: 'Share my ride',
      body: ListView(
        children: [
          Text(
            'Send a live-tracking link so someone can follow your trip in real '
            'time. They will not see any phone numbers or rider details.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _phoneInput,
                  label: 'Add a mobile (optional)',
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: IconButton.filledTonal(
                  onPressed: _addPhone,
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
          if (_phones.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final p in _phones)
                  Chip(
                    label: Text(p),
                    onDeleted: () => setState(() => _phones.remove(p)),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Link expires in',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1h')),
              ButtonSegment(value: 6, label: Text('6h')),
              ButtonSegment(value: 24, label: Text('24h')),
            ],
            selected: {_expiresInHours},
            onSelectionChanged: (s) =>
                setState(() => _expiresInHours = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _phones.isEmpty ? 'Create tracking link' : 'Share via SMS',
            icon: Icons.share_location,
            loading: _creating,
            onPressed: _creating ? null : _create,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Active links', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          sharesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorState(
              message: messageForError(e),
              onRetry: () => ref.invalidate(tripSharesProvider(widget.tripId)),
            ),
            data: (shares) => shares.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No active links.'),
                  )
                : Column(
                    children: [
                      for (final s in shares)
                        _ShareRow(share: s, onRevoke: () => _revoke(s)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share, required this.onRevoke});

  final TripShare share;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.link),
        title: Text(share.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          share.expiresAt == null
              ? 'No expiry'
              : 'Expires ${share.expiresAt!.toFriendly()}',
        ),
        trailing: IconButton(
          tooltip: 'Revoke',
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: onRevoke,
        ),
      ),
    );
  }
}
