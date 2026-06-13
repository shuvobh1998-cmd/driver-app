import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/earnings_providers.dart';
import '../../data/models/invoice.dart';

/// The trip's tax invoice: company header, itemised lines, total, and a button
/// that downloads + opens the PDF in the device viewer.
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  bool _openingPdf = false;

  Future<void> _openPdf() async {
    setState(() => _openingPdf = true);
    try {
      final path = await ref
          .read(earningsApiProvider)
          .downloadInvoicePdf(widget.tripId);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        context.showInfoSnack('No app available to open the PDF.');
      }
    } catch (e) {
      if (mounted) context.showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _openingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoiceProvider(widget.tripId));
    return AppScaffold(
      title: 'Invoice',
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: () => ref.invalidate(invoiceProvider(widget.tripId)),
        ),
        data: (invoice) => _Body(invoice: invoice),
      ),
      bottomBar: PrimaryButton(
        label: 'Open PDF',
        icon: Icons.picture_as_pdf,
        loading: _openingPdf,
        onPressed: async.hasValue ? _openPdf : null,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(invoice.companyName, style: theme.textTheme.titleMedium),
        Text(invoice.companyAddress, style: theme.textTheme.bodySmall),
        Text('GSTIN: ${invoice.gstin}', style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(invoice.invoiceNumber, style: theme.textTheme.labelLarge),
            if (invoice.issuedAt != null)
              Text(
                invoice.issuedAt!.toFriendly(),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const Divider(height: AppSpacing.lg),
        if (invoice.pickupAddress != null)
          _TripRow(icon: Icons.trip_origin, text: invoice.pickupAddress!),
        if (invoice.dropAddress != null)
          _TripRow(icon: Icons.place, text: invoice.dropAddress!),
        const SizedBox(height: AppSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final line in invoice.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(line.label, style: theme.textTheme.bodyMedium),
                        Text(
                          formatPaise(line.amount),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: theme.textTheme.titleMedium),
                    Text(
                      formatPaise(invoice.total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            StatusBadge(
              label: invoice.paymentMethod.label,
              tone: StatusTone.neutral,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(
              label: invoice.paymentStatus.name.toUpperCase(),
              tone: StatusTone.info,
            ),
          ],
        ),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
