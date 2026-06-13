import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/core_providers.dart';
import '../../../../design_system/design_system.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../../earnings/data/earnings_providers.dart';
import '../../../earnings/data/models/earnings_enums.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../onboarding_kyc/data/models/onboarding_enums.dart';
import '../../../onboarding_kyc/data/models/vehicle.dart';
import '../../../onboarding_kyc/data/onboarding_providers.dart';
import '../../../trips/presentation/controllers/active_trip_controller.dart';
import '../../data/driver_home_providers.dart';
import '../../data/models/driver_state.dart';
import '../controllers/driver_home_controller.dart';
import '../widgets/driver_go_online_button.dart';
import '../widgets/driver_map.dart';
import '../widgets/location_permission_primer.dart';
import '../widgets/vehicle_selector.dart';

/// The driver home: a map centered on self, the big Go Online / Go Offline
/// control, a vehicle selector (when there is more than one approved vehicle),
/// today's earnings chip, and an always-visible online/offline status header.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  String? _selectedVehicleId;

  List<Vehicle> _activeVehicles(List<Vehicle> all) =>
      all.where((v) => v.status == VehicleStatus.active).toList();

  String? _resolveSelected(DriverState? s, List<Vehicle> active) {
    if (s != null && s.vehicleId != null) return s.vehicleId;
    if (_selectedVehicleId != null &&
        active.any((v) => v.publicId == _selectedVehicleId)) {
      return _selectedVehicleId;
    }
    return active.isEmpty ? null : active.first.publicId;
  }

  Future<void> _toggle(DriverState current, List<Vehicle> active) async {
    final controller = ref.read(driverHomeControllerProvider.notifier);
    if (current.isOnline) {
      await controller.goOffline();
      return;
    }

    final vehicleId = _resolveSelected(current, active);
    if (vehicleId == null) {
      context.showInfoSnack(
        'Finish onboarding and get a vehicle approved first.',
      );
      return;
    }

    final service = ref.read(liveLocationServiceProvider);
    if (!await service.ensurePermission()) {
      if (!mounted) return;
      final proceed = await showLocationPrimer(context);
      if (!proceed || !mounted) return;
      if (!await service.ensurePermission()) {
        if (mounted) {
          context.showInfoSnack(
            'Location permission is needed to go online. Enable it in Settings.',
          );
        }
        return;
      }
    }
    await controller.goOnline(vehicleId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(driverHomeControllerProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final centerAsync = ref.watch(initialMapCenterProvider);
    final transitioning = ref.watch(driverTransitioningProvider);
    final hasActiveTrip = ref.watch(hasActiveTripProvider);

    // Surface go-online/offline failures (KYC_INCOMPLETE, VEHICLE_NOT_APPROVED…)
    // as a snackbar without leaving the screen.
    ref.listen(driverHomeControllerProvider, (_, next) {
      if (next is AsyncError) context.showErrorSnack(next.error!);
    });

    final state = stateAsync.value;
    final vehicles = vehiclesAsync.value ?? const <Vehicle>[];
    final active = _activeVehicles(vehicles);
    final selected = _resolveSelected(state, active);
    final online = state?.isOnline ?? false;
    final center = state?.location != null
        ? LatLng(state!.location!.lat, state.location!.lng)
        : centerAsync.value ?? const LatLng(22.5726, 88.3639);

    return AppScaffold(
      title: l10n.appTitle,
      padded: false,
      actions: [
        const _NotificationsBell(),
        IconButton(
          tooltip: 'Earnings',
          icon: const Icon(Icons.account_balance_wallet),
          onPressed: () => context.push(Routes.earnings),
        ),
        IconButton(
          tooltip: 'Trip history',
          icon: const Icon(Icons.history),
          onPressed: () => context.push(Routes.tripHistory),
        ),
        IconButton(
          tooltip: 'Carpool',
          icon: const Icon(Icons.groups),
          onPressed: () => context.push(Routes.carpool),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: () => context.push(Routes.settings),
        ),
      ],
      body: Stack(
        children: [
          Positioned.fill(
            child: DriverMap(center: center, online: online),
          ),
          // Status header — always glanceable.
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.md,
            child: SafeArea(
              child: _StatusHeader(
                status: state?.status ?? DriverStatus.offline,
              ),
            ),
          ),
          if (online && !hasActiveTrip)
            const Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.md,
              child: SafeArea(child: _SearchingChip()),
            ),
          if (hasActiveTrip)
            Positioned(
              top: AppSpacing.xl,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: SafeArea(
                child: _ResumeTripBanner(
                  onTap: () => context.push(Routes.activeTrip),
                ),
              ),
            ),
          // Bottom control panel.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ControlPanel(
              online: online,
              busy: transitioning,
              activeVehicles: active,
              selectedVehicleId: selected,
              onVehicleChanged: (id) => setState(() => _selectedVehicleId = id),
              onToggle: (state == null || transitioning)
                  ? null
                  : () => _toggle(state, active),
              loadingState: transitioning,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notifications bell with an unread badge, driven by [unreadCountControllerProvider].
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountControllerProvider).value ?? 0;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});
  final DriverStatus status;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: StatusBadge(label: status.label, tone: status.tone),
    );
  }
}

class _SearchingChip extends StatelessWidget {
  const _SearchingChip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(999),
      elevation: 1,
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Searching for trips…'),
          ],
        ),
      ),
    );
  }
}

class _ResumeTripBanner extends StatelessWidget {
  const _ResumeTripBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You have an active trip — tap to resume',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.online,
    required this.busy,
    required this.activeVehicles,
    required this.selectedVehicleId,
    required this.onVehicleChanged,
    required this.onToggle,
    required this.loadingState,
  });

  final bool online;
  final bool busy;
  final bool loadingState;
  final List<Vehicle> activeVehicles;
  final String? selectedVehicleId;
  final ValueChanged<String> onVehicleChanged;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoOnline = activeVehicles.isNotEmpty;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: AppSpacing.radiusCircular),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _EarningsChip(),
                  const Spacer(),
                  if (online)
                    Text(
                      "You're online",
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!online)
                VehicleSelector(
                  vehicles: activeVehicles,
                  selectedId: selectedVehicleId,
                  onChanged: onVehicleChanged,
                  enabled: !busy,
                ),
              if (!canGoOnline && !online) ...[
                const _OnboardingHint(),
                const SizedBox(height: AppSpacing.sm),
              ],
              DriverGoOnlineButton(
                isOnline: online,
                enabled: online || canGoOnline,
                loading: loadingState,
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsChip extends ConsumerWidget {
  const _EarningsChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(earningsProvider(EarningsPeriod.today));
    final label = today.when(
      loading: () => 'Today · …',
      error: (_, _) => 'Today · ₹—',
      data: (s) => 'Today · ${formatPaise(s.netEarning)}',
    );
    return ActionChip(
      avatar: const Icon(Icons.account_balance_wallet, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onPressed: () => context.push(Routes.earnings),
    );
  }
}

class _OnboardingHint extends StatelessWidget {
  const _OnboardingHint();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.approvalStatus),
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Get a vehicle approved to go online. Tap to see what’s left.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
