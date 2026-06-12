import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../data/models/onboarding_enums.dart';

/// A [StatusBadge] driven by the overall [KycStatus] — color + icon + label.
class KycStatusBadge extends StatelessWidget {
  const KycStatusBadge({super.key, required this.status});

  final KycStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusBadge(label: status.label, tone: status.tone);
}
