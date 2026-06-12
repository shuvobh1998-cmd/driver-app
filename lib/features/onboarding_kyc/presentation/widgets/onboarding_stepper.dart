import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// One step in the onboarding progress.
class OnboardingStep {
  const OnboardingStep({required this.label, required this.done});
  final String label;
  final bool done;
}

/// A compact horizontal progress stepper for the onboarding hub
/// (① Documents ② Vehicle ③ Review). Each completed step shows a check; the
/// first incomplete step is highlighted as current.
class OnboardingStepper extends StatelessWidget {
  const OnboardingStepper({super.key, required this.steps});

  final List<OnboardingStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = steps.indexWhere((s) => !s.done);
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: steps[i - 1].done
                    ? AppColors.success
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          _StepDot(index: i, step: steps[i], isCurrent: i == currentIndex),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.step,
    required this.isCurrent,
  });

  final int index;
  final OnboardingStep step;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    if (step.done) {
      color = AppColors.success;
    } else if (isCurrent) {
      color = theme.colorScheme.primary;
    } else {
      color = theme.colorScheme.outlineVariant;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: step.done
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(step.label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
