import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/moderation_service.dart';
import '../widgets/confirm_dialogs.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key, required this.moderationService});

  final ModerationService moderationService;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  @override
  void initState() {
    super.initState();
    widget.moderationService.refresh();
  }

  Future<void> _resolve(ContentReport report, String status) async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: status == 'resolved'
          ? strings.moderationResolveTitle
          : strings.moderationDismissTitle,
      message: strings.moderationResolveConfirm,
      confirmLabel: status == 'resolved'
          ? strings.moderationResolve
          : strings.moderationDismiss,
    );
    if (confirmed != true || !mounted) return;
    final error = await widget.moderationService.resolveReport(
      reportId: report.id,
      status: status,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? strings.moderationUpdated),
      ),
    );
  }

  Future<void> _deactivateListing(ContentReport report) async {
    if (report.targetType != 'listing') return;
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.moderationDeactivateListing,
      message: strings.moderationDeactivateListingConfirm,
      confirmLabel: strings.moderationDeactivateListing,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final error =
        await widget.moderationService.deactivateListing(report.targetId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? strings.moderationListingDeactivated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final service = widget.moderationService;

    return Scaffold(
      appBar: AppBar(title: Text(strings.moderationTitle)),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final status in const [
                        'open',
                        'resolved',
                        'dismissed',
                        'all',
                      ]) ...[
                        ChoiceChip(
                          label: Text(_statusLabel(strings, status)),
                          selected: service.statusFilter == status,
                          onSelected: (_) => service.setStatusFilter(status),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded(
                child: service.isLoading && service.reports.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : service.error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                strings.moderationLoadFailed,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : service.reports.isEmpty
                            ? Center(
                                child: Text(
                                  strings.moderationEmpty,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: service.refresh,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: service.reports.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final report = service.reports[index];
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Chip(
                                                  label: Text(report.targetType),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(
                                                    _statusLabel(
                                                      strings,
                                                      report.status,
                                                    ),
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                const Spacer(),
                                                Text(
                                                  _relative(strings, report.createdAt),
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: theme
                                                        .colorScheme.outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              report.reason,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${strings.moderationReporter}: ${report.reporterLogin}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            Text(
                                              '${strings.moderationTarget}: ${report.targetId}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color:
                                                    theme.colorScheme.outline,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (report.status == 'open') ...[
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  FilledButton(
                                                    onPressed: () => _resolve(
                                                      report,
                                                      'resolved',
                                                    ),
                                                    child: Text(
                                                      strings.moderationResolve,
                                                    ),
                                                  ),
                                                  OutlinedButton(
                                                    onPressed: () => _resolve(
                                                      report,
                                                      'dismissed',
                                                    ),
                                                    child: Text(
                                                      strings.moderationDismiss,
                                                    ),
                                                  ),
                                                  if (report.targetType ==
                                                      'listing')
                                                    TextButton(
                                                      onPressed: () =>
                                                          _deactivateListing(
                                                        report,
                                                      ),
                                                      child: Text(
                                                        strings
                                                            .moderationDeactivateListing,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(AppStrings strings, String status) {
    return switch (status) {
      'open' => strings.moderationStatusOpen,
      'resolved' => strings.moderationStatusResolved,
      'dismissed' => strings.moderationStatusDismissed,
      'all' => strings.moderationStatusAll,
      _ => status,
    };
  }

  String _relative(AppStrings strings, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return strings.isRu ? 'только что' : 'just now';
    }
    if (diff.inHours < 1) {
      return strings.isRu
          ? '${diff.inMinutes} мин'
          : '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return strings.isRu ? '${diff.inHours} ч' : '${diff.inHours}h';
    }
    return strings.isRu ? '${diff.inDays} дн' : '${diff.inDays}d';
  }
}
