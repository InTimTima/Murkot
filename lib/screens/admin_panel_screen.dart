import 'dart:async';

import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/admin_service.dart';
import '../services/moderation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/feedback_service.dart';
import '../utils/helpers.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/murkot_toast.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'media_viewer_screen.dart';
import 'moderation_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key, this.currentLogin});

  final String? currentLogin;

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _admin = AdminService();
  final _moderation = ModerationService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _admin.refresh(login: widget.currentLogin);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _admin.dispose();
    _moderation.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _admin.setQuery(value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _admin.refreshUsers();
    });
  }

  Future<void> _openReports() async {
    await _moderation.checkModerator();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModerationScreen(moderationService: _moderation),
      ),
    );
    if (mounted) unawaited(_admin.refreshOverview());
  }

  Future<void> _toggleDisabled(AdminUserRow user) async {
    final strings = context.strings;
    if (user.isAdmin) return;
    final disable = !user.isDisabled;
    final confirmed = await showConfirmDialog(
      context: context,
      title: disable ? strings.adminDisableTitle : strings.adminEnableTitle,
      message: disable
          ? strings.adminDisableConfirm(user.login)
          : strings.adminEnableConfirm(user.login),
      confirmLabel: disable ? strings.adminDisable : strings.adminEnable,
      isDestructive: disable,
    );
    if (confirmed != true || !mounted) return;
    final error = await _admin.setUserDisabled(
      userId: user.id,
      disabled: disable,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (disable
                  ? strings.adminDisableDone(user.login)
                  : strings.adminEnableDone(user.login)),
        ),
      ),
    );
  }

  Future<void> _deactivateListings(AdminUserRow user) async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.adminDeactivateListings,
      message: strings.adminDeactivateListingsConfirm(user.login),
      confirmLabel: strings.adminDeactivateListings,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final error = await _admin.deactivateUserListings(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? strings.adminDeactivateListingsDone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const MurkotBackButton(),
        title: Text(strings.adminTitle),
        actions: [
          IconButton(
            tooltip: strings.retry,
            onPressed: () => _admin.refresh(login: widget.currentLogin),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _admin,
        builder: (context, _) {
          if (_admin.isAdmin == false) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  strings.adminDenied,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }

          if (_admin.isAdmin != true && _admin.overview == null) {
            return const Center(child: MurkotLoader(size: 44));
          }

          return RefreshIndicator(
            onRefresh: () => _admin.refresh(login: widget.currentLogin),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_admin.error != null) ...[
                  _ErrorBanner(
                    message: strings.adminLoadFailed,
                    detail: _admin.error!,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_admin.overview != null)
                  _StatsGrid(overview: _admin.overview!, strings: strings),
                const SizedBox(height: 20),
                _QuickActions(
                  reportsOpen: _admin.overview?.reportsOpen ?? 0,
                  onReports: _openReports,
                ),
                const _FeedbackSection(),
                const SizedBox(height: 24),
                Text(
                  strings.adminUsers,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: strings.adminSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.adminOnlineOnly),
                  value: _admin.onlineOnly,
                  onChanged: _admin.setOnlineOnly,
                ),
                const SizedBox(height: 8),
                if (_admin.isLoading && _admin.users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: MurkotLoader(size: 36)),
                  )
                else if (_admin.users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      strings.adminUsersEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                else
                  for (final user in _admin.users)
                    _UserCard(
                      user: user,
                      strings: strings,
                      onToggleDisabled: () => _toggleDisabled(user),
                      onDeactivateListings: () => _deactivateListings(user),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.detail});

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsSql = detail.contains('PGRST202') ||
        detail.contains('Could not find the function') ||
        detail.contains('admin_overview') ||
        detail.contains('is_app_admin');
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              needsSql
                  ? context.strings.adminNeedsMigration
                  : message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.overview, required this.strings});

  final AdminOverview overview;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final chatsHint =
        '${overview.conversationsDirect} ${strings.adminDirect} · '
        '${overview.conversationsGroup} ${strings.adminGroups} · '
        '${overview.conversationsChannel} ${strings.adminChannels}';

    final cards = <_StatSpec>[
      _StatSpec(
        Icons.wifi_tethering,
        '${overview.usersOnline}',
        strings.adminOnlineNow,
      ),
      _StatSpec(
        Icons.people_outline,
        '${overview.usersTotal}',
        strings.adminUsersTotal,
      ),
      _StatSpec(
        Icons.person_add_alt_1_outlined,
        '${overview.usersToday}',
        strings.adminUsersToday,
      ),
      _StatSpec(
        Icons.date_range_outlined,
        '${overview.usersWeek}',
        strings.adminUsersWeek,
      ),
      _StatSpec(
        Icons.campaign_outlined,
        '${overview.listingsActive}',
        strings.adminListingsActive,
        hint: strings.adminListingsHint(overview.listingsTotal),
      ),
      _StatSpec(
        Icons.work_outline,
        '${overview.projectsTotal}',
        strings.adminProjects,
      ),
      _StatSpec(
        Icons.forum_outlined,
        '${overview.conversationsTotal}',
        strings.adminChats,
        hint: chatsHint,
      ),
      _StatSpec(
        Icons.chat_bubble_outline,
        '${overview.messagesToday}',
        strings.adminMessagesToday,
        hint: strings.adminMessagesHint(overview.messagesTotal),
      ),
      _StatSpec(
        Icons.flag_outlined,
        '${overview.reportsOpen}',
        strings.adminReportsOpen,
      ),
      _StatSpec(
        Icons.favorite_outline,
        '${overview.swipesToday}',
        strings.adminSwipesToday,
      ),
      if (overview.usersDisabled > 0)
        _StatSpec(
          Icons.block,
          '${overview.usersDisabled}',
          strings.adminDisabledCount,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final spec in cards)
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth,
                child: _StatCard(spec: spec),
              ),
          ],
        );
      },
    );
  }
}

class _StatSpec {
  const _StatSpec(this.icon, this.value, this.label, {this.hint});

  final IconData icon;
  final String value;
  final String label;
  final String? hint;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.spec});

  final _StatSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MurkotColors.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(spec.icon, color: MurkotColors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.label,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (spec.hint != null)
                    Text(
                      spec.hint!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.reportsOpen,
    required this.onReports,
  });

  final int reportsOpen;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(Icons.gavel_outlined, color: theme.colorScheme.primary),
        title: Text(strings.moderationTitle),
        subtitle: Text(strings.adminReportsHint(reportsOpen)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onReports,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.strings,
    required this.onToggleDisabled,
    required this.onDeactivateListings,
  });

  final AdminUserRow user;
  final AppStrings strings;
  final VoidCallback onToggleDisabled;
  final VoidCallback onDeactivateListings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = strings.isRu;
    final seen = user.isOnline
        ? strings.adminOnlineNow
        : formatLastSeen(user.lastSeenAt, isRu: isRu);
    final city = user.city?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                final url = user.avatarUrl;
                if (url != null && url.isNotEmpty) {
                  MediaViewerScreen.open(context, urls: [url], initialIndex: 0);
                }
              },
              child: AvatarDisplay(
                name: user.login,
                avatarPath: user.avatarUrl,
                avatarEmoji: user.avatarEmoji,
                radius: 22,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.login,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (user.isAdmin) ...[
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(strings.adminBadge),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(fontSize: 11),
                        ),
                      ],
                      if (user.isDisabled) ...[
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(strings.adminDisabledBadge),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          backgroundColor: theme.colorScheme.errorContainer,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      seen,
                      if (city != null && city.isNotEmpty) city,
                      strings.adminUserListings(
                        user.listingsActive,
                        user.listingsTotal,
                      ),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            if (!user.isAdmin)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'disable') onToggleDisabled();
                  if (value == 'listings') onDeactivateListings();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'disable',
                    child: Text(
                      user.isDisabled
                          ? strings.adminEnable
                          : strings.adminDisable,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'listings',
                    child: Text(strings.adminDeactivateListings),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackSection extends StatefulWidget {
  const _FeedbackSection();

  @override
  State<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<_FeedbackSection> {
  final _service = FeedbackService();
  List<FeedbackLetter> _letters = const [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.listForAdmin();
    if (!mounted) return;
    setState(() {
      _letters = list;
      _loading = false;
    });
  }

  void _openLetter(FeedbackLetter l) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.surface, theme.colorScheme.surfaceContainerHighest]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AvatarDisplay(name: l.authorLogin, avatarPath: l.avatarUrl, avatarEmoji: l.avatarEmoji, radius: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.authorLogin, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(l.createdAt.toLocal().toString().split('.').first, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                ])),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
                child: Text(l.text, style: theme.textTheme.bodyMedium),
              ),
              if (l.photoUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(l.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async { await Supabase.instance.client.from('feedback_letters').delete().eq('id', l.id); if (context.mounted) { Navigator.pop(ctx); _load(); } }, icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error), label: Text('Удалить', style: TextStyle(color: theme.colorScheme.error)))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(onPressed: () { Navigator.pop(ctx); MurkotToast.show(context, 'Ответ — напиши в ЛС автору'); }, icon: const Icon(Icons.reply, size: 16), label: const Text('Ответить'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.mail_outline, color: theme.colorScheme.primary),
            title: Text(strings.isRu ? 'Письма' : 'Letters'),
            subtitle: Text(_loading ? '...' : '${_letters.length}'),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (_loading)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: MurkotLoader(size: 24)))
            else if (_letters.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(strings.isRu ? 'Пока нет писем' : 'No letters yet', style: TextStyle(color: theme.colorScheme.outline)))
            else
              for (final l in _letters)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: AvatarDisplay(name: l.authorLogin, avatarPath: l.avatarUrl, avatarEmoji: l.avatarEmoji, radius: 18),
                    title: Text(l.authorLogin, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (l.photoUrl != null) Padding(padding: const EdgeInsets.only(top: 6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(l.photoUrl!, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()))),
                    ]),
                    isThreeLine: true,
                    onTap: () => _openLetter(l),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: Text(strings.retry)),
            ),
          ],
        ],
      ),
    );
  }
}
