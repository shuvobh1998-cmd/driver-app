import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';

/// Severity of a [StatusBadge]. Each maps to a color **and** an icon so the
/// status reads without relying on color alone.
enum StatusTone { neutral, success, warning, danger, info }

/// A pill that communicates state with color + icon + label together
/// (KYC status, trip state, online/offline, payout status, …).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      StatusTone.success => (AppColors.success, Icons.check_circle),
      StatusTone.warning => (AppColors.warning, Icons.schedule),
      StatusTone.danger => (AppColors.danger, Icons.error),
      StatusTone.info => (AppColors.info, Icons.info),
      StatusTone.neutral => (Theme.of(context).colorScheme.outline, Icons.circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
