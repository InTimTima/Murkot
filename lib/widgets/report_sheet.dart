import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../services/analytics_service.dart';

Future<void> showReportSheet({
  required BuildContext context,
  required String targetType,
  required String targetId,
  String? targetLabel,
}) async {
  final strings = context.strings;
  final reasons = <String>[
    strings.reportReasonSpam,
    strings.reportReasonAbuse,
    strings.reportReasonFake,
    strings.reportReasonOther,
  ];
  String selected = reasons.first;

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.reportTitle,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (targetLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      targetLabel,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final reason in reasons)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        selected == reason
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      title: Text(reason),
                      onTap: () => setModal(() => selected = reason),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(strings.reportSubmit),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await Supabase.instance.client.rpc(
      'submit_report',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reason': selected,
      },
    );
    await AnalyticsService.instance.track('report_submit', {
      'type': targetType,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.reportThanks)),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.reportFailed)),
    );
  }
}
