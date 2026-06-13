import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/carpool_providers.dart';
import '../../data/models/carpool_enums.dart';
import '../../data/models/scheduled_trip.dart';
import '../controllers/my_trips_controller.dart';

/// Edits the mutable fields of an OPEN, unbooked carpool trip: departure, seats,
/// price, notes and preferences. (Route changes are rare and left to re-posting.)
class ScheduledTripEditScreen extends ConsumerWidget {
  const ScheduledTripEditScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scheduledTripDetailProvider(tripId));
    return AppScaffold(
      title: 'Edit trip',
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(scheduledTripDetailProvider(tripId)),
        ),
        data: (trip) {
          if (!trip.isEditable) {
            return const EmptyState(
              icon: Icons.lock,
              title: 'Locked',
              message:
                  'A trip can only be edited while it is open and has no bookings.',
            );
          }
          return _EditForm(trip: trip);
        },
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.trip});

  final ScheduledTrip trip;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _seats;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  late DateTime _departureAt;
  late bool _ac;
  late GenderPreference _gender;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _seats = TextEditingController(text: '${t.totalSeats}');
    _price = TextEditingController(text: '${(t.pricePerSeat / 100).round()}');
    _notes = TextEditingController(text: t.notes ?? '');
    _departureAt = t.departureAt.toLocal();
    _ac = t.preferences.ac ?? false;
    _gender = t.preferences.gender ?? GenderPreference.any;
  }

  @override
  void dispose() {
    _seats.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureAt.isBefore(now) ? now : _departureAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureAt),
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(carpoolApiProvider)
          .update(
            widget.trip.id,
            departureAt: _departureAt,
            totalSeats: int.parse(_seats.text.trim()),
            pricePerSeat: (num.parse(_price.text.trim()) * 100).round(),
            notes: _notes.text.trim(),
            preferences: TripPreferences(ac: _ac, gender: _gender),
          );
      ref.invalidate(scheduledTripDetailProvider(widget.trip.id));
      unawaited(ref.read(myTripsControllerProvider.notifier).refresh());
      if (mounted) {
        context.showInfoSnack('Trip updated.');
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Departure'),
            subtitle: Text(_departureAt.toFriendly()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDeparture,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _seats,
                  label: 'Total seats',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.event_seat,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1 || n > 8) return '1–8 seats';
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter a price';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Air-conditioned'),
            value: _ac,
            onChanged: (v) => setState(() => _ac = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Who can book', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<GenderPreference>(
            segments: [
              for (final g in GenderPreference.values)
                ButtonSegment(value: g, label: Text(g.label)),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _notes, label: 'Notes (optional)'),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Save changes',
            icon: Icons.save,
            loading: _submitting,
            onPressed: _submitting ? null : _save,
          ),
        ],
      ),
    );
  }
}
