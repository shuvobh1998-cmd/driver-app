import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/design_system.dart';

/// The dominant control on the home screen: a large, state-aware Go Online /
/// Go Offline button with a haptic tap. Green to go online, red to step off.
/// Disabled (with a reason) until the driver is approved.
class DriverGoOnlineButton extends StatelessWidget {
  const DriverGoOnlineButton({
    super.key,
    required this.isOnline,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final bool isOnline;
  final bool loading;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.danger : AppColors.brand;
    final label = isOnline ? 'Go Offline' : 'Go Online';
    final icon = isOnline ? Icons.stop_circle : Icons.bolt;

    return SizedBox(
      width: double.infinity,
      height: 72,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppSpacing.radiusCircular),
          ),
        ),
        onPressed: (!enabled || loading || onPressed == null)
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onPressed!.call();
              },
        child: loading
            ? const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
