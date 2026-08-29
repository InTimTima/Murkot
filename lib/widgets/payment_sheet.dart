import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../screens/offer_screen.dart';
import '../services/billing_service.dart';
import 'murkot_toast.dart';

/// Opens a YooKassa-style checkout sheet. Returns true if purchase succeeded.
Future<bool> showPaymentSheet(
  BuildContext context, {
  required MurkotProduct product,
  BillingService? billing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _PaymentSheet(
      product: product,
      billing: billing ?? BillingService(),
    ),
  );
  return result == true;
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.product, required this.billing});

  final MurkotProduct product;
  final BillingService billing;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  bool _paying = false;
  bool _accepted = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = context.strings.isRu;
    final info = productInfo(widget.product);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: MurkotColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(info.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title(isRu),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isRu ? 'Оплата через ЮKassa' : 'Pay via YooKassa',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  info.priceLabel(isRu),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: MurkotColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                info.description(isRu),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: _paying
                  ? null
                  : (v) => setState(() => _accepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                isRu
                    ? 'Согласен с офертой и условиями оплаты'
                    : 'I accept the offer and payment terms',
                style: theme.textTheme.bodySmall,
              ),
              secondary: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OfferScreen(),
                    ),
                  );
                },
                child: Text(isRu ? 'Читать' : 'Read'),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: (!_accepted || _paying) ? null : _pay,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: MurkotColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _paying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isRu
                          ? 'Оплатить ${info.priceLabel(true)}'
                          : 'Pay ${info.priceLabel(false)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              isRu
                  ? 'После оплаты доступ активируется сразу. Реквизиты и оферта — на странице «Оферта и платежи».'
                  : 'Access activates right after payment. Legal details are on the Offer page.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    final ok = await widget.billing.purchase(widget.product);
    if (!mounted) return;
    setState(() => _paying = false);
    final isRu = context.strings.isRu;
    final info = productInfo(widget.product);
    if (ok) {
      MurkotToast.show(
        context,
        isRu
            ? '«${info.titleRu}» активировано'
            : '“${info.titleEn}” activated',
      );
      Navigator.pop(context, true);
    } else {
      MurkotToast.show(
        context,
        isRu ? 'Оплата не прошла' : 'Payment failed',
      );
    }
  }
}
