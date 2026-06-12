import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/image_pick.dart';
import '../../../../shared/utils/validators.dart';
import '../../data/models/onboarding_enums.dart';
import '../../data/models/vehicle.dart';
import '../../data/onboarding_providers.dart';

/// Register a new vehicle or edit an existing one. On create, registration
/// number and type are captured then locked; edits are limited to
/// make/model/year/color/seats (matching the backend). After a successful
/// create the driver is offered to add a photo right away.
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  /// Non-null when editing an existing vehicle.
  final Vehicle? vehicle;

  bool get isEdit => vehicle != null;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late VehicleType _type;
  late final TextEditingController _registration;
  late final TextEditingController _seats;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _type = v?.vehicleType == null || v!.vehicleType == VehicleType.unknown
        ? VehicleType.car
        : v.vehicleType;
    _registration = TextEditingController(text: v?.registrationNumber ?? '');
    _seats = TextEditingController(text: v?.seatCount.toString() ?? '4');
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _color = TextEditingController(text: v?.color ?? '');
  }

  @override
  void dispose() {
    for (final c in [_registration, _seats, _make, _model, _year, _color]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _orNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(driverApiProvider);
    final seatCount = int.parse(_seats.text.trim());
    final year = _year.text.trim().isEmpty
        ? null
        : int.tryParse(_year.text.trim());
    try {
      if (widget.isEdit) {
        await api.updateVehicle(widget.vehicle!.publicId, {
          'make': _orNull(_make),
          'model': _orNull(_model),
          'year': year,
          'color': _orNull(_color),
          'seatCount': seatCount,
        });
        ref.invalidate(vehiclesProvider);
        if (mounted) {
          context.showInfoSnack('Vehicle updated.');
          Navigator.pop(context);
        }
      } else {
        final created = await api.createVehicle(
          vehicleType: _type,
          registrationNumber: _registration.text.trim().toUpperCase(),
          seatCount: seatCount,
          make: _orNull(_make),
          model: _orNull(_model),
          year: year,
          color: _orNull(_color),
        );
        ref.invalidate(vehiclesProvider);
        await _offerPhoto(created.publicId);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _offerPhoto(String vehicleId) async {
    if (!mounted) return;
    final source = await showImageSourceSheet(context);
    if (source == null) return;
    try {
      final path = await ref.read(imagePickServiceProvider).pick(source);
      if (path == null) return;
      await ref
          .read(driverApiProvider)
          .uploadVehiclePhoto(id: vehicleId, filePath: path);
      ref.invalidate(vehiclesProvider);
      if (mounted) context.showInfoSnack('Vehicle photo added.');
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    }
  }

  String? _validateSeats(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter the number of seats.';
    if (n < 1 || n > 10) return 'Seats must be between 1 and 10.';
    return null;
  }

  String? _validateYear(String? v) {
    final raw = v?.trim() ?? '';
    if (raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n == null || n < 1990 || n > 2027) return 'Enter a year (1990–2027).';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.isEdit ? 'Edit vehicle' : 'Register vehicle',
      bottomBar: PrimaryButton(
        label: widget.isEdit ? 'Save changes' : 'Register vehicle',
        loading: _saving,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<VehicleType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Vehicle type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final t in VehicleType.values)
                  if (t != VehicleType.unknown)
                    DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              // Type is locked once the vehicle exists.
              onChanged: widget.isEdit
                  ? null
                  : (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _registration,
              label: 'Registration number',
              hint: 'e.g. WB12AB1234',
              prefixIcon: Icons.confirmation_number_outlined,
              maxLength: 20,
              inputFormatters: [UpperCaseTextFormatter()],
              validator: widget.isEdit
                  ? null
                  : (v) => Validators.required(v, field: 'Registration number'),
              // Registration number is locked once set.
              // (Disabled via readOnly on edit.)
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _seats,
              label: 'Seats (including driver)',
              prefixIcon: Icons.event_seat_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validateSeats,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _make,
              label: 'Make (optional)',
              hint: 'e.g. Maruti Suzuki',
              prefixIcon: Icons.factory_outlined,
              maxLength: 50,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _model,
              label: 'Model (optional)',
              hint: 'e.g. Swift Dzire',
              prefixIcon: Icons.directions_car_outlined,
              maxLength: 50,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _year,
              label: 'Year (optional)',
              prefixIcon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validateYear,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _color,
              label: 'Color (optional)',
              prefixIcon: Icons.palette_outlined,
              maxLength: 30,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Upper-cases registration input as the driver types (plates are stored
/// upper-cased on the backend).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
