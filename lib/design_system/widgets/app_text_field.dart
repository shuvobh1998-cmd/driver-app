import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standard text input with inline validation support, used across the KYC,
/// vehicle and auth forms. Wraps [TextFormField] so the design-system
/// [InputDecorationTheme] is applied consistently.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.inputFormatters,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;

  /// Fixed, non-editable prefix shown inside the field (e.g. the `+91` dial
  /// code on phone inputs).
  final String? prefixText;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  /// Caps input length. The character counter is hidden so it doesn't clutter
  /// dense forms.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        prefixText: prefixText,
        suffixIcon: suffix,
        counterText: maxLength == null ? null : '',
      ),
    );
  }
}

/// A national-mobile-number field for India: fixed `+91` prefix, digits-only,
/// capped at 10 characters. The controller still holds just the 10 digits;
/// callers wrap it with `Phone.toE164` before sending.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    this.label = 'Mobile number',
    this.validator,
  });

  final TextEditingController controller;
  final String? label;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: '10-digit mobile',
      prefixIcon: Icons.phone,
      prefixText: '+91 ',
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
    );
  }
}
