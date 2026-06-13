import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../controllers/active_trip_controller.dart';

/// Rate the rider 1–5 with an optional comment. Submits once — `ALREADY_RATED`
/// is treated as success (the rating is already stored) so the driver isn't
/// stuck on a trip they've rated.
class RateRiderScreen extends ConsumerStatefulWidget {
  const RateRiderScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<RateRiderScreen> createState() => _RateRiderScreenState();
}

class _RateRiderScreenState extends ConsumerState<RateRiderScreen> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      context.showInfoSnack('Tap a star to rate the rider.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(activeTripControllerProvider.notifier)
          .rateRider(rating: _rating, comment: _comment.text.trim());
      if (mounted) _finish('Thanks for rating!');
    } on AppFailure catch (f) {
      // Already rated counts as done — don't trap the driver.
      if (f.code == 'ALREADY_RATED') {
        if (mounted) _finish('You already rated this rider.');
        return;
      }
      if (mounted) {
        setState(() => _submitting = false);
        context.showErrorSnack(f);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showErrorSnack(e);
    }
  }

  void _finish(String message) {
    context.showInfoSnack(message);
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Rate rider',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'How was your rider?',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 44,
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _comment,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Add a comment (optional)',
            ),
          ),
        ],
      ),
      bottomBar: PrimaryButton(
        label: 'Submit rating',
        loading: _submitting,
        onPressed: _submit,
      ),
    );
  }
}
