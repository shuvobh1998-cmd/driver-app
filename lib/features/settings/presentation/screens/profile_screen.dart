import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/image_pick.dart';
import '../../../../shared/utils/validators.dart';
import '../../../auth/data/models/gender.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/user_providers.dart';

/// View + edit the signed-in driver's profile, including avatar upload. Reads
/// the full profile from `/users/me/profile` and writes changes back, keeping
/// the cached session user in sync via [AuthController.refreshUser].
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    return AppScaffold(
      title: 'Profile',
      body: profile.when(
        loading: () => const LoadingState(message: 'Loading your profile…'),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (data) =>
            _ProfileForm(key: ValueKey(data.publicId), profile: data),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({super.key, required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;
  late final TextEditingController _emName;
  late final TextEditingController _emPhone;
  late Gender? _gender;

  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _first = TextEditingController(text: p.firstName ?? '');
    _last = TextEditingController(text: p.lastName ?? '');
    _email = TextEditingController(text: p.email ?? '');
    _emName = TextEditingController(text: p.emergencyContactName ?? '');
    _emPhone = TextEditingController(text: p.emergencyContactPhone ?? '');
    _gender = (p.gender == Gender.unknown) ? null : p.gender;
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _emName, _emPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim().isEmpty ? null : _last.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'gender': _gender?.wireValue,
        'emergencyContactName': _emName.text.trim().isEmpty
            ? null
            : _emName.text.trim(),
        'emergencyContactPhone': _emPhone.text.trim().isEmpty
            ? null
            : _emPhone.text.trim(),
      };
      await ref.read(userApiProvider).updateProfile(patch);
      ref.invalidate(userProfileProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) context.showInfoSnack('Profile updated.');
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final path = await ImagePickService().pick(source);
      if (path == null) return;
      await ref.read(userApiProvider).uploadAvatar(path);
      ref.invalidate(userProfileProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) context.showInfoSnack('Photo updated.');
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String? _emergencyPhoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return Validators.phone(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(child: _avatar(p)),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(p.phone, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _first,
            label: 'First name',
            prefixIcon: Icons.person,
            validator: (v) => Validators.required(v, field: 'First name'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _last,
            label: 'Last name (optional)',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _email,
            label: 'Email (optional)',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<Gender>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender (optional)',
              prefixIcon: Icon(Icons.wc),
            ),
            items: const [
              DropdownMenuItem(value: Gender.male, child: Text('Male')),
              DropdownMenuItem(value: Gender.female, child: Text('Female')),
              DropdownMenuItem(value: Gender.other, child: Text('Other')),
              DropdownMenuItem(
                value: Gender.preferNotToSay,
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (g) => setState(() => _gender = g),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Emergency contact',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _emName,
            label: 'Contact name',
            prefixIcon: Icons.contact_emergency,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _emPhone,
            label: 'Contact phone',
            prefixIcon: Icons.phone_in_talk,
            keyboardType: TextInputType.phone,
            validator: _emergencyPhoneValidator,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Save changes',
            loading: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _avatar(UserProfile p) {
    final hasAvatar = p.avatarUrl != null && p.avatarUrl!.isNotEmpty;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: hasAvatar ? NetworkImage(p.avatarUrl!) : null,
          child: hasAvatar ? null : const Icon(Icons.person, size: 48),
        ),
        Material(
          color: Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _uploadingAvatar ? null : _changeAvatar,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _uploadingAvatar
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
