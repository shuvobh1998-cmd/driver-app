import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../controllers/trip_offer_controller.dart';
import '../widgets/countdown_ring.dart';

/// Full-screen incoming-trip takeover: a countdown ring, the pickup + distance,
/// and two big decisions — Accept or Decline. Loud and time-boxed (sound +
/// haptics), it auto-dismisses when the offer expires.
class IncomingOfferScreen extends ConsumerStatefulWidget {
  const IncomingOfferScreen({super.key});

  @override
  ConsumerState<IncomingOfferScreen> createState() =>
      _IncomingOfferScreenState();
}

class _IncomingOfferScreenState extends ConsumerState<IncomingOfferScreen> {
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    // Loud, attention-grabbing arrival.
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  Future<void> _accept() async {
    if (_answering) return;
    setState(() => _answering = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(tripOfferControllerProvider.notifier).accept();
      if (mounted) context.pushReplacement(Routes.activeTrip);
    } catch (e) {
      if (!mounted) return;
      setState(() => _answering = false);
      context.showErrorSnack(e);
    }
  }

  void _decline() {
    if (_answering) return;
    _answering = true;
    HapticFeedback.selectionClick();
    ref.read(tripOfferControllerProvider.notifier).decline();
    if (mounted && context.canPop()) context.pop();
  }

  void _onExpired() {
    if (_answering) return;
    ref.read(tripOfferControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(tripOfferControllerProvider);
    final theme = Theme.of(context);

    // The offer cleared elsewhere (expiry / external) — leave the takeover.
    ref.listen(tripOfferControllerProvider, (_, next) {
      if (next == null && !_answering && mounted && context.canPop()) {
        context.pop();
      }
    });

    if (offer == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              CountdownRing(
                start: offer.receivedAt,
                expiresAt: offer.expiresAt,
                onExpired: _onExpired,
                size: 140,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('New trip request', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  StatusBadge(
                    label: offer.vehicleType.label,
                    tone: StatusTone.info,
                  ),
                  if (offer.distanceMeters != null)
                    StatusBadge(
                      label: _distance(offer.distanceMeters!),
                      tone: StatusTone.neutral,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.trip_origin,
                    color: AppColors.success,
                  ),
                  title: const Text('Pickup'),
                  subtitle: Text(offer.pickup.display),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: _answering ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        backgroundColor: AppColors.brand,
                      ),
                      onPressed: _answering ? null : _accept,
                      child: _answering
                          ? const SizedBox(
                              height: 26,
                              width: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _distance(int meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km away'
      : '$meters m away';
}
