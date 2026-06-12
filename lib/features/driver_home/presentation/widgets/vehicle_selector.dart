import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../onboarding_kyc/data/models/vehicle.dart';

/// Lets a driver with more than one approved vehicle pick which one they are
/// driving today. Hidden when there is a single (or no) choice — one decision
/// per screen.
class VehicleSelector extends StatelessWidget {
  const VehicleSelector({
    super.key,
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (vehicles.length < 2) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId,
            isExpanded: true,
            icon: const Icon(Icons.directions_car),
            onChanged: enabled
                ? (v) {
                    if (v != null) onChanged(v);
                  }
                : null,
            items: [
              for (final v in vehicles)
                DropdownMenuItem(
                  value: v.publicId,
                  child: Text(
                    '${v.title} · ${v.registrationNumber}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
