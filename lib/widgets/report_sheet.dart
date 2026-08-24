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
  final otherController = TextEditingController();

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final isOther = selected == strings.reportReasonOther;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                  if (isOther) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otherController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: strings.isRu ? 'Опиши проблему…' : 'Describe the issue…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      if (isOther && otherController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(strings.isRu ? 'Опиши причину' : 'Please describe')));
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
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
  final otherText = otherController.text.trim();
  otherController.dispose();

  if (confirmed != true || !context.mounted) return;

  final reasonToSend = (selected == strings.reportReasonOther && otherText.isNotEmpty)
      ? '${strings.reportReasonOther}: $otherText'
      : selected;
  try {
    await Supabase.instance.client.rpc(
      'submit_report',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reason': reasonToSend,
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
