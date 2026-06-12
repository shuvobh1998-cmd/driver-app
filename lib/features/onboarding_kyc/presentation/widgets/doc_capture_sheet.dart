import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/onboarding_enums.dart';

/// What the capture sheet returns: the chosen image source plus an optional
/// document number (for types that collect one).
typedef DocCaptureResult = ({ImageSource source, String? docNumber});

/// Bottom sheet for capturing a KYC document: an optional document-number
/// field (for Aadhaar/DL/PAN) and Camera / Gallery actions. The image is
/// compressed by the caller's upload pipeline (≤1024px JPEG q80).
class DocCaptureSheet extends StatefulWidget {
  const DocCaptureSheet({
    super.key,
    required this.docType,
    this.initialDocNumber,
  });

  final KycDocType docType;
  final String? initialDocNumber;

  static Future<DocCaptureResult?> show(
    BuildContext context, {
    required KycDocType docType,
    String? initialDocNumber,
  }) {
    return showModalBottomSheet<DocCaptureResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DocCaptureSheet(
          docType: docType,
          initialDocNumber: initialDocNumber,
        ),
      ),
    );
  }

  @override
  State<DocCaptureSheet> createState() => _DocCaptureSheetState();
}

class _DocCaptureSheetState extends State<DocCaptureSheet> {
  late final TextEditingController _number = TextEditingController(
    text: widget.initialDocNumber ?? '',
  );

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String? get _docNumber {
    final v = _number.text.trim();
    return v.isEmpty ? null : v;
  }

  void _pick(ImageSource source) =>
      Navigator.pop(context, (source: source, docNumber: _docNumber));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.docType.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.docType.collectsNumber) ...[
              AppTextField(
                controller: _number,
                label: 'Document number (optional)',
                prefixIcon: Icons.tag,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
