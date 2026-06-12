import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/image_pick.dart';
import '../../data/models/vehicle.dart';
import '../../data/onboarding_providers.dart';
import '../widgets/vehicle_card.dart';
import 'vehicle_form_screen.dart';

/// Lists the driver's registered vehicles with their approval status, and lets
/// them add, edit, remove or attach a photo to a vehicle.
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(vehiclesProvider);
    await ref.read(vehiclesProvider.future);
  }

  void _openForm(BuildContext context, {Vehicle? vehicle}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleFormScreen(vehicle: vehicle),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('${vehicle.title} (${vehicle.registrationNumber})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(driverApiProvider).deleteVehicle(vehicle.publicId);
      ref.invalidate(vehiclesProvider);
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  Future<void> _addPhoto(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;
    try {
      final path = await ref.read(imagePickServiceProvider).pick(source);
      if (path == null) return;
      await ref
          .read(driverApiProvider)
          .uploadVehiclePhoto(id: vehicle.publicId, filePath: path);
      ref.invalidate(vehiclesProvider);
      if (context.mounted) context.showInfoSnack('Vehicle photo added.');
    } catch (e) {
      if (context.mounted) context.showErrorSnack(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);

    return AppScaffold(
      title: 'My vehicles',
      bottomBar: PrimaryButton(
        label: 'Add vehicle',
        icon: Icons.add,
        onPressed: () => _openForm(context),
      ),
      body: vehicles.when(
        loading: () => const LoadingState(message: 'Loading your vehicles…'),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => _refresh(ref),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles yet',
              message: 'Register the vehicle you drive to get approved.',
              actionLabel: 'Add vehicle',
              onAction: () => _openForm(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              children: [
                const SizedBox(height: AppSpacing.sm),
                for (final v in list)
                  VehicleCard(
                    vehicle: v,
                    onEdit: () => _openForm(context, vehicle: v),
                    onDelete: () => _delete(context, ref, v),
                    onAddPhoto: () => _addPhoto(context, ref, v),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
