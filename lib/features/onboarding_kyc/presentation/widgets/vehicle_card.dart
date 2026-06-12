import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/onboarding_enums.dart';
import '../../data/models/vehicle.dart';

/// A vehicle summary card: photo, plate, type/seat info and a status badge,
/// with edit / remove actions and a tap-to-add-photo affordance.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    this.onEdit,
    this.onDelete,
    this.onAddPhoto,
  });

  final Vehicle vehicle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = vehicle.photoUrl != null && vehicle.photoUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _photo(context, hasPhoto),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        vehicle.registrationNumber,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${vehicle.vehicleType.label} · ${vehicle.seatCount} seats',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StatusBadge(
                        label: vehicle.status.label,
                        tone: vehicle.status.tone,
                      ),
                    ],
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Remove'),
                        ),
                    ],
                  ),
              ],
            ),
            if (vehicle.status == VehicleStatus.inactive &&
                vehicle.rejectedReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                vehicle.rejectedReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
            if (!hasPhoto && onAddPhoto != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add photo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, bool hasPhoto) {
    const size = 64.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: hasPhoto
            ? Image.network(vehicle.photoUrl!, fit: BoxFit.cover)
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.directions_car_outlined),
              ),
      ),
    );
  }
}
