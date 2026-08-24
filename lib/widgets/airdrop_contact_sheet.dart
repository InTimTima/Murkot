import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../models/user_preview.dart';
import 'avatar_display.dart';

/// Confirmation before sending a listing/project response as the first DM.
/// Returns edited message or null if cancelled.
Future<String?> showAirdropContactSheet({
  required BuildContext context,
  required UserPreview recipient,
  required String subjectTitle,
  required String previewText,
}) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => _AirdropContactSheet(
      recipient: recipient,
      subjectTitle: subjectTitle,
      previewText: previewText,
    ),
  );
  return result;
}

class _AirdropContactSheet extends StatefulWidget {
  const _AirdropContactSheet({
    required this.recipient,
    required this.subjectTitle,
    required this.previewText,
  });

  final UserPreview recipient;
  final String subjectTitle;
  final String previewText;

  @override
  State<_AirdropContactSheet> createState() => _AirdropContactSheetState();
}

class _AirdropContactSheetState extends State<_AirdropContactSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.previewText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.respondEyebrow,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.respondTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.respondSubtitle(widget.recipient.login, widget.subjectTitle),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLight
                      ? [
                          MurkotColors.cream,
                          MurkotColors.pulp.withValues(alpha: 0.65),
                        ]
                      : [
                          Colors.white10,
                          MurkotColors.orange.withValues(alpha: 0.18),
                        ],
                ),
                border: Border.all(
                  color: isLight ? Colors.black12 : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  AvatarDisplay(
                    name: widget.recipient.login,
                    avatarPath: widget.recipient.avatarUrl,
                    avatarEmoji: widget.recipient.avatarEmoji,
                    radius: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recipient.login,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: strings.isRu ? 'Твоё письмо' : 'Your message',
                hintText: widget.previewText,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.isRu ? 'Напиши хоть что-то' : 'Write something')));
                        return;
                      }
                      Navigator.pop(context, text);
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(strings.respondSend),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
