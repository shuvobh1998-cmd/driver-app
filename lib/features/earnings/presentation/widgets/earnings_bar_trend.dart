import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/money.dart';

/// One labelled bar in [EarningsBarTrend]. [value] is paise.
class EarningsBar {
  const EarningsBar({required this.label, required this.value});

  final String label;
  final int value;
}

/// A minimal, dependency-free horizontal bar chart comparing a handful of money
/// values. Bars scale to the largest value; zero values still render a label.
class EarningsBarTrend extends StatelessWidget {
  const EarningsBarTrend({super.key, required this.bars});

  final List<EarningsBar> bars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);

    return Column(
      children: [
        for (final bar in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(bar.label, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : bar.value / max,
                      minHeight: 14,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 84,
                  child: Text(
                    formatPaise(bar.value),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
