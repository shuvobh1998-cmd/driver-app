import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/trip_enums.dart';

/// The single next lifecycle action a driver can take, derived purely from the
/// trip [TripStatus]. "One decision per screen": the active-trip screen shows
/// exactly one of these.
enum TripAction {
  arrived,
  start,
  end,
  none;

  /// The one action allowed at [status], or [none] for terminal states.
  static TripAction forStatus(TripStatus status) => switch (status) {
    TripStatus.accepted => TripAction.arrived,
    TripStatus.arrived => TripAction.start,
    TripStatus.started => TripAction.end,
    _ => TripAction.none,
  };

  String get label => switch (this) {
    TripAction.arrived => "I've arrived",
    TripAction.start => 'Start trip',
    TripAction.end => 'End trip',
    TripAction.none => '',
  };

  IconData get icon => switch (this) {
    TripAction.arrived => Icons.location_on,
    TripAction.start => Icons.play_circle,
    TripAction.end => Icons.flag,
    TripAction.none => Icons.check,
  };
}

/// Big, full-width primary control whose label/colour follow the current
/// [TripAction]. [loading] shows an inline spinner; a null [onPressed] disables it.
class NextActionButton extends StatelessWidget {
  const NextActionButton({
    super.key,
    required this.action,
    required this.onPressed,
    this.loading = false,
  });

  final TripAction action;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (action == TripAction.none) return const SizedBox.shrink();
    final color = action == TripAction.end ? AppColors.danger : AppColors.brand;

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppSpacing.radiusCircular),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    action.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
