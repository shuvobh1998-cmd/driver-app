import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../driver_home/data/driver_home_providers.dart';
import '../../../onboarding_kyc/data/models/onboarding_enums.dart';
import '../../../onboarding_kyc/data/models/vehicle.dart';
import '../../../onboarding_kyc/data/onboarding_providers.dart';
import '../../data/carpool_providers.dart';
import '../../data/models/carpool_enums.dart';
import '../../data/models/scheduled_trip.dart';
import '../widgets/location_picker_field.dart';

/// Form to post a scheduled carpool trip: route, departure, vehicle, seats,
/// price and preferences. On success it pops `true` so the list can refresh.
class PostScheduledTripScreen extends ConsumerStatefulWidget {
  const PostScheduledTripScreen({super.key});

  @override
  ConsumerState<PostScheduledTripScreen> createState() =>
      _PostScheduledTripScreenState();
}

class _PostScheduledTripScreenState
    extends ConsumerState<PostScheduledTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originAddress = TextEditingController();
  final _destAddress = TextEditingController();
  final _seats = TextEditingController(text: '3');
  final _price = TextEditingController();
  final _notes = TextEditingController();

  LatLngPoint? _origin;
  LatLngPoint? _destination;
  DateTime? _departureAt;
  String? _vehicleId;
  bool _ac = false;
  GenderPreference _gender = GenderPreference.any;
  bool _submitting = false;

  @override
  void dispose() {
    _originAddress.dispose();
    _destAddress.dispose();
    _seats.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<Vehicle> _approved(List<Vehicle> all) =>
      all.where((v) => v.status == VehicleStatus.active).toList();

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _departureAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(() {
      _departureAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit(List<Vehicle> approved) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_origin == null || _destination == null) {
      context.showInfoSnack('Pick both a pickup and a drop on the map.');
      return;
    }
    if (_departureAt == null) {
      context.showInfoSnack('Choose a departure time.');
      return;
    }
    if (_vehicleId == null) {
      context.showInfoSnack('Select a vehicle for this trip.');
      return;
    }
    final rupees = num.tryParse(_price.text.trim()) ?? 0;
    final paise = (rupees * 100).round();

    setState(() => _submitting = true);
    try {
      await ref
          .read(carpoolApiProvider)
          .create(
            origin: _origin!,
            originAddress: _originAddress.text.trim(),
            destination: _destination!,
            destAddress: _destAddress.text.trim(),
            departureAt: _departureAt!,
            vehicleId: _vehicleId!,
            totalSeats: int.parse(_seats.text.trim()),
            pricePerSeat: paise,
            notes: _notes.text.trim(),
            preferences: TripPreferences(ac: _ac, gender: _gender),
          );
      if (mounted) {
        context.showInfoSnack('Trip posted.');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final approved = _approved(vehiclesAsync.value ?? const []);
    final centerAsync = ref.watch(initialMapCenterProvider);
    final LatLng? center = centerAsync.value;

    // Default the vehicle to the only approved one.
    if (_vehicleId == null && approved.length == 1) {
      _vehicleId = approved.first.publicId;
    }

    return AppScaffold(
      title: 'Post a carpool trip',
      body: approved.isEmpty
          ? const EmptyState(
              icon: Icons.directions_car,
              title: 'No approved vehicle',
              message:
                  'You need an approved vehicle before posting a carpool trip.',
            )
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  LocationPickerField(
                    label: 'Pickup',
                    icon: Icons.trip_origin,
                    point: _origin,
                    addressController: _originAddress,
                    initialCenter: center,
                    onPicked: (p) => setState(() => _origin = p),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LocationPickerField(
                    label: 'Drop',
                    icon: Icons.place,
                    point: _destination,
                    addressController: _destAddress,
                    initialCenter: center,
                    onPicked: (p) => setState(() => _destination = p),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DepartureTile(
                    departureAt: _departureAt,
                    onTap: _pickDeparture,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _VehicleDropdown(
                    vehicles: approved,
                    selectedId: _vehicleId,
                    onChanged: (id) => setState(() => _vehicleId = id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _seats,
                          label: 'Total seats',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.event_seat,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1 || n > 8) {
                              return '1–8 seats';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          controller: _price,
                          label: 'Price / seat',
                          keyboardType: TextInputType.number,
                          prefixText: '₹ ',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) return 'Enter a price';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Air-conditioned'),
                    value: _ac,
                    onChanged: (v) => setState(() => _ac = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Who can book',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<GenderPreference>(
                    segments: [
                      for (final g in GenderPreference.values)
                        ButtonSegment(value: g, label: Text(g.label)),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (s) =>
                        setState(() => _gender = s.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _notes,
                    label: 'Notes (optional)',
                    hint: 'Pickup landmark, luggage limits, etc.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Post trip',
                    icon: Icons.publish,
                    loading: _submitting,
                    onPressed: _submitting ? null : () => _submit(approved),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }
}

class _DepartureTile extends StatelessWidget {
  const _DepartureTile({required this.departureAt, required this.onTap});

  final DateTime? departureAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Departure', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    departureAt == null
                        ? 'Choose date & time'
                        : departureAt!.toFriendly(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: departureAt == null
                          ? theme.colorScheme.outline
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _VehicleDropdown extends StatelessWidget {
  const _VehicleDropdown({
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: 'Vehicle',
        prefixIcon: Icon(Icons.directions_car),
      ),
      items: [
        for (final v in vehicles)
          DropdownMenuItem(
            value: v.publicId,
            child: Text('${v.title} · ${v.registrationNumber}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
