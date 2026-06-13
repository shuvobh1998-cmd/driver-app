import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/trip.dart';
import '../controllers/active_trip_controller.dart';

/// Bottom sheet that collects the rider's 4-digit start OTP and starts the trip.
/// Returns the started [Trip] on success, or null if dismissed. Wrong/missing
/// codes (`OTP_INVALID` / `OTP_REQUIRED`) render inline so the driver can retry
/// without losing the sheet.
Future<Trip?> showOtpStartSheet(BuildContext context) {
  return showModalBottomSheet<Trip>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _OtpStartSheet(),
    ),
  );
}

class _OtpStartSheet extends ConsumerStatefulWidget {
  const _OtpStartSheet();

  @override
  ConsumerState<_OtpStartSheet> createState() => _OtpStartSheetState();
}

class _OtpStartSheetState extends ConsumerState<_OtpStartSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final otp = _controller.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'Enter the 4-digit code from the rider.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final trip = await ref
          .read(activeTripControllerProvider.notifier)
          .startTrip(otp);
      if (mounted) Navigator.of(context).pop(trip);
    } on AppFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = f.message;
      });
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
            Text('Start trip', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ask the rider for their 4-digit code and enter it to start.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              enabled: !_submitting,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 16,
                fontWeight: FontWeight.w700,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Start trip',
              icon: Icons.play_circle,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
