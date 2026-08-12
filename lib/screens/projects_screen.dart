import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../models/message.dart';
import '../models/project.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/projects_service.dart';
import '../services/settings_service.dart';
import '../utils/board_tab_bus.dart';
import '../widgets/airdrop_contact_sheet.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/dev_card.dart';
import '../widgets/murkot_decor.dart';
import 'chat_screen.dart';

/// Roles offered as quick-add suggestions when publishing a project.
const kRoleSuggestions = [
  'Frontend',
  'Backend',
  'Mobile',
  'Fullstack',
  'UI/UX',
  'QA',
  'DevOps',
  'ML',
  'PM',
  'Маркетинг',
];

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.projectsService,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final ProjectsService projectsService;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.projectsService.refresh();
    boardCreateIntent.addListener(_onCreateIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCreateIntent());
  }

  @override
  void dispose() {
    boardCreateIntent.removeListener(_onCreateIntent);
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    widget.projectsService.clearFilters();
  }

  Future<void> _openFiltersSheet() async {
    final service = widget.projectsService;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final strings = context.strings;
            final theme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.projectsFilters,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (service.availableSkills.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(strings.skillsLabel,
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final skill in service.availableSkills)
                              FilterChip(
                                label: Text(skill),
                                selected: service.skillFilter != null &&
                                    service.skillFilter!.toLowerCase() ==
                                        skill.toLowerCase(),
                                onSelected: (on) =>
                                    service.setSkillFilter(on ? skill : null),
                              ),
                          ],
                        ),
                      ],
                      if (service.availableRoles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(strings.projectsLookingForLabel,
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(strings.projectsFilterRoleAll),
                              selected: service.roleFilter == null,
                              onSelected: (_) => service.setRoleFilter(null),
                            ),
                            for (final role in service.availableRoles)
                              FilterChip(
                                label: Text(role),
                                selected: service.roleFilter != null &&
                                    service.roleFilter!.toLowerCase() ==
                                        role.toLowerCase(),
                                onSelected: (on) =>
                                    service.setRoleFilter(on ? role : null),
                              ),
                          ],
                        ),
                      ],
                      if (service.availableCities.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(strings.cityLabel,
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(strings.listingFilterCityAll),
                              selected: service.cityFilter == null,
                              onSelected: (_) => service.setCityFilter(null),
                            ),
                            for (final city in service.availableCities)
                              FilterChip(
                                label: Text(city),
                                selected: service.cityFilter != null &&
                                    service.cityFilter!.toLowerCase() ==
                                        city.toLowerCase(),
                                onSelected: (on) =>
                                    service.setCityFilter(on ? city : null),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (service.activeChipFilterCount > 0)
                            TextButton(
                              onPressed: _clearFilters,
                              child: Text(strings.clearFilters),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text(strings.projectsFiltersDone),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onCreateIntent() {
    if (boardCreateIntent.value != BoardCreateIntent.project) return;
    boardCreateIntent.value = BoardCreateIntent.none;
    if (!mounted) return;
    _create();
  }

  Future<void> _contactAuthor(Project project) async {
    final strings = context.strings;
    final preview = strings.projectContactPrefill(project.name);
    final confirmed = await showAirdropContactSheet(
      context: context,
      recipient: project.author,
      subjectTitle: project.name,
      previewText: preview,
    );
    if (!confirmed || !mounted) return;

    try {
      final conversation =
          await widget.chatService.openDirectChat(project.author);
      await widget.chatService.sendMessage(
        conversationId: conversation.id,
        type: MessageType.text,
        content: preview,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatScreen(
            conversation: conversation,
            chatService: widget.chatService,
            blacklistService: widget.blacklistService,
            presenceService: widget.presenceService,
            currentUserLogin: widget.currentUserLogin,
            settingsService: widget.settingsService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.openChatFailed)),
      );
    }
  }

  Future<void> _delete(Project project) async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.projectDelete,
      message: strings.projectDeleteConfirm,
      confirmLabel: strings.deleteAction,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final error = await widget.projectsService.deleteProject(project.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? strings.projectDeleted)),
    );
  }

  Future<void> _create() async {
    final saved = await showProjectEditorSheet(
      context: context,
      projectsService: widget.projectsService,
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? context.strings.projectPublished : context.strings.projectUpdated,
        ),
      ),
    );
  }

  Future<void> _edit(Project project) async {
    final saved = await showProjectEditorSheet(
      context: context,
      projectsService: widget.projectsService,
      existing: project,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.projectUpdated)),
      );
    }
  }

  void _openProject(Project project) {
    final service = widget.projectsService;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _FinderProjectDetail(
        project: project,
        isMine: service.isMine(project),
        onContact: () {
          Navigator.pop(context);
          _contactAuthor(project);
        },
        onEdit: () {
          Navigator.pop(context);
          _edit(project);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(project);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final service = widget.projectsService;
    final isLight = theme.brightness == Brightness.light;

    return ListenableBuilder(
      listenable: Listenable.merge([service, widget.blacklistService]),
      builder: (context, _) {
        final projects = service.projects
            .where((p) => !widget.blacklistService.isBlocked(p.author.login))
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.projectsFinderHeading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    strings.projectsObjectsCount(projects.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _ProjectsToolbar(
              service: service,
              searchController: _searchController,
              onClearFilters: _clearFilters,
              onOpenFilters: _openFiltersSheet,
            ),
            Divider(
              height: 1,
              color: isLight ? Colors.black12 : Colors.white12,
            ),
            Expanded(
              child: service.error != null
                  ? _ErrorState(
                      text: strings.projectLoadFailed,
                      onRetry: service.refresh,
                    )
                  : service.isLoading && projects.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : projects.isEmpty
                          ? _EmptyState(
                              text: service.hasActiveFilters
                                  ? strings.projectsFilterEmpty
                                  : strings.projectsEmpty,
                              actionLabel: service.hasActiveFilters
                                  ? strings.clearFilters
                                  : strings.projectsEmptyAction,
                              onAction: service.hasActiveFilters
                                  ? _clearFilters
                                  : _create,
                            )
                          : RefreshIndicator(
                              onRefresh: service.refresh,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final crossAxisCount = width >= 900
                                      ? 3
                                      : width >= 560
                                          ? 2
                                          : 1;
                                  return GridView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 12, 12, 12),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisExtent: 132,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: projects.length,
                                    itemBuilder: (context, index) {
                                      final project = projects[index];
                                      return _FinderProjectTile(
                                        project: project,
                                        isMine: service.isMine(project),
                                        index: index,
                                        onOpen: () => _openProject(project),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
            ),
            Material(
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: InkWell(
                  onTap: _create,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isLight ? Colors.black12 : Colors.white12,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          strings.projectCreate,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _relativeTime(AppStrings strings, DateTime time) {
  final diff = DateTime.now().difference(time);
  final isRu = strings.isRu;
  if (diff.inMinutes < 1) return isRu ? 'только что' : 'just now';
  if (diff.inHours < 1) {
    return isRu ? '${diff.inMinutes} мин назад' : '${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    return isRu ? '${diff.inHours} ч назад' : '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return isRu ? '${diff.inDays} дн назад' : '${diff.inDays}d ago';
  }
  return '${time.day.toString().padLeft(2, '0')}.'
      '${time.month.toString().padLeft(2, '0')}.${time.year}';
}

Future<void> _openLink(String url) async {
  var target = url.trim();
  if (!target.startsWith('http://') && !target.startsWith('https://')) {
    target = 'https://$target';
  }
  final uri = Uri.tryParse(target);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ProjectsToolbar extends StatefulWidget {
  const _ProjectsToolbar({
    required this.service,
    required this.searchController,
    required this.onClearFilters,
    required this.onOpenFilters,
  });

  final ProjectsService service;
  final TextEditingController searchController;
  final VoidCallback onClearFilters;
  final VoidCallback onOpenFilters;

  @override
  State<_ProjectsToolbar> createState() => _ProjectsToolbarState();
}

class _ProjectsToolbarState extends State<_ProjectsToolbar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onText);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final service = widget.service;
    final filterCount = service.activeChipFilterCount;
    final hasQuery = service.searchQuery.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.searchController,
              onChanged: service.setSearchQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: strings.projectsSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: widget.searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.searchController.clear();
                          service.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: IconButton(
              tooltip: strings.projectsFilters,
              onPressed: widget.onOpenFilters,
              icon: Icon(
                filterCount > 0
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                color: filterCount > 0 ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          PopupMenuButton<ProjectSort>(
            tooltip: service.sort == ProjectSort.relevance
                ? strings.projectsSortRelevance
                : strings.projectsSortNewest,
            onSelected: service.setSort,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ProjectSort.newest,
                child: Text(strings.projectsSortNewest),
              ),
              PopupMenuItem(
                value: ProjectSort.relevance,
                enabled: hasQuery,
                child: Text(strings.projectsSortRelevance),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.sort,
                color: service.sort == ProjectSort.relevance
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (service.hasActiveFilters)
            IconButton(
              tooltip: strings.clearFilters,
              onPressed: widget.onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Stack(
            alignment: Alignment.center,
            children: [
              CitrusSlice(size: 72, opacity: 0.55),
              StretchCatSilhouette(width: 96, opacity: 0.35),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.text, required this.onRetry});

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(strings.retry),
          ),
        ],
      ),
    );
  }
}

String _projectMetaLine(Project project) {
  if (project.lookingFor.isNotEmpty) {
    return project.lookingFor.take(3).join(' · ');
  }
  if (project.stack.isNotEmpty) {
    return project.stack.take(3).join(' / ');
  }
  return project.author.login;
}

Color _projectAccent(String seed) {
  const accents = [
    MurkotColors.orange,
    MurkotColors.yellow,
    MurkotColors.deepOrange,
    MurkotColors.leaf,
    Color(0xFFC45C26),
    Color(0xFF8B6914),
  ];
  return accents[seed.hashCode.abs() % accents.length];
}

/// Compact Finder-style object tile — tap opens the detail sheet.
class _FinderProjectTile extends StatefulWidget {
  const _FinderProjectTile({
    required this.project,
    required this.isMine,
    required this.index,
    required this.onOpen,
  });

  final Project project;
  final bool isMine;
  final int index;
  final VoidCallback onOpen;

  @override
  State<_FinderProjectTile> createState() => _FinderProjectTileState();
}

class _FinderProjectTileState extends State<_FinderProjectTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 280 + (widget.index.clamp(0, 8) * 40)),
    );
    Future<void>.delayed(Duration(milliseconds: widget.index * 35), () {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final accent = _projectAccent(widget.project.id);
    final subtitle = widget.project.description.trim().isEmpty
        ? widget.project.author.login
        : widget.project.description.trim();
    final meta = _projectMetaLine(widget.project);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic)),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: Material(
            color: isLight ? Colors.white.withValues(alpha: 0.72) : Colors.white10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white12,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onOpen,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  children: [
                    _FinderFolderIcon(accent: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.project.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.north_east_rounded,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.72),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.isMine) ...[
                                Text(
                                  strings.listingMineBadge,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  ' · ',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  meta,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinderFolderIcon extends StatelessWidget {
  const _FinderFolderIcon({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.95),
            Color.lerp(accent, MurkotColors.yellow, 0.35)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.folder_rounded, color: Colors.white, size: 26),
    );
  }
}

class _FinderProjectDetail extends StatelessWidget {
  const _FinderProjectDetail({
    required this.project,
    required this.isMine,
    required this.onContact,
    required this.onEdit,
    required this.onDelete,
  });

  final Project project;
  final bool isMine;
  final VoidCallback onContact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final accent = _projectAccent(project.id);
    final demo = project.demoUrl?.trim() ?? '';
    final repo = project.repoUrl?.trim() ?? '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _FinderFolderIcon(accent: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.projectsFinderLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.0,
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          project.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AvatarDisplay(
                    name: project.author.login,
                    avatarPath: project.author.avatarUrl,
                    avatarEmoji: project.author.avatarEmoji,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.author.login,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            if (project.author.city != null &&
                                project.author.city!.isNotEmpty)
                              project.author.city!,
                            _relativeTime(strings, project.createdAt),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  if (isMine)
                    Text(
                      strings.listingMineBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(project.description, style: theme.textTheme.bodyMedium),
              ],
              if (project.stack.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in project.stack)
                      Chip(
                        label: Text(tag),
                        labelStyle: theme.textTheme.bodySmall,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              if (project.lookingFor.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strings.projectLookingForLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final role in project.lookingFor)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MurkotColors.leaf.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: MurkotColors.leaf.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: MurkotColors.leaf,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (demo.isNotEmpty || repo.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (demo.isNotEmpty)
                      ActionChip(
                        avatar:
                            const Icon(Icons.play_circle_outline, size: 16),
                        label: Text(strings.projectDemoLabel),
                        onPressed: () => _openLink(demo),
                      ),
                    if (repo.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.code, size: 16),
                        label: Text(strings.projectRepoLabel),
                        onPressed: () => _openLink(repo),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if (isMine)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(strings.listingEditAction),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(strings.deleteAction),
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: onContact,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(strings.projectContactAuthor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the project editor. Returns `true` if created, `false` if updated.
Future<bool?> showProjectEditorSheet({
  required BuildContext context,
  required ProjectsService projectsService,
  Project? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ProjectEditorSheet(
      projectsService: projectsService,
      existing: existing,
    ),
  );
}

class _ProjectEditorSheet extends StatefulWidget {
  const _ProjectEditorSheet({
    required this.projectsService,
    this.existing,
  });

  final ProjectsService projectsService;
  final Project? existing;

  @override
  State<_ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<_ProjectEditorSheet> {
  late final List<String> _stack;
  late final List<String> _lookingFor;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _stackController = TextEditingController();
  final _roleController = TextEditingController();
  late final TextEditingController _demoController;
  late final TextEditingController _repoController;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _stack = List.of(existing?.stack ?? const <String>[]);
    _lookingFor = List.of(existing?.lookingFor ?? const <String>[]);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _demoController = TextEditingController(text: existing?.demoUrl ?? '');
    _repoController = TextEditingController(text: existing?.repoUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _stackController.dispose();
    _roleController.dispose();
    _demoController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  void _addTag(List<String> target, TextEditingController controller,
      String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    final exists = target.any((s) => s.toLowerCase() == tag.toLowerCase());
    if (!exists) {
      setState(() => target.add(tag));
    }
    controller.clear();
  }

  Future<void> _publish() async {
    final strings = context.strings;
    final name = _nameController.text.trim();
    if (name.length < 3) {
      setState(() => _nameError = strings.projectNameRequired);
      return;
    }

    setState(() {
      _nameError = null;
      _saving = true;
    });

    final existing = widget.existing;
    final error = existing == null
        ? await widget.projectsService.createProject(
            name: name,
            description: _descriptionController.text.trim(),
            stack: _stack,
            lookingFor: _lookingFor,
            demoUrl: _demoController.text.trim(),
            repoUrl: _repoController.text.trim(),
          )
        : await widget.projectsService.updateProject(
            id: existing.id,
            name: name,
            description: _descriptionController.text.trim(),
            stack: _stack,
            lookingFor: _lookingFor,
            demoUrl: _demoController.text.trim(),
            repoUrl: _repoController.text.trim(),
          );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.projectSaveFailed)),
        );
      return;
    }
    Navigator.pop(context, existing == null);
  }

  Widget _tagEditor({
    required List<String> tags,
    required TextEditingController controller,
    required String hint,
    required List<String> suggestions,
  }) {
    final visibleSuggestions = suggestions
        .where(
            (s) => !tags.any((added) => added.toLowerCase() == s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() => tags.remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addTag(tags, controller, controller.text),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => _addTag(tags, controller, value),
        ),
        if (visibleSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final suggestion in visibleSuggestions.take(12))
                ActionChip(
                  label: Text(suggestion),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addTag(tags, controller, suggestion),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? strings.projectEdit : strings.projectNewTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: strings.projectNameLabel,
                  hintText: strings.projectNameHint,
                  errorText: _nameError,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 8,
                maxLength: 3000,
                decoration: InputDecoration(
                  labelText: strings.listingDescriptionLabel,
                  hintText: strings.projectDescriptionHint,
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.skillsLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              _tagEditor(
                tags: _stack,
                controller: _stackController,
                hint: strings.skillAddHint,
                suggestions: kSkillSuggestions,
              ),
              const SizedBox(height: 16),
              Text(
                strings.projectLookingForLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              _tagEditor(
                tags: _lookingFor,
                controller: _roleController,
                hint: strings.projectLookingForHint,
                suggestions: kRoleSuggestions,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _demoController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: strings.projectDemoLabel,
                  hintText: strings.linkHint,
                  prefixIcon: const Icon(Icons.play_circle_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repoController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: strings.projectRepoLabel,
                  hintText: strings.linkHint,
                  prefixIcon: const Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _publish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? strings.save : strings.projectCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
