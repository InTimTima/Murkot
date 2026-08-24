import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/listings_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/board_tab_bus.dart';
import '../widgets/airdrop_contact_sheet.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/dev_card.dart';
import '../widgets/guest_gate.dart';
import '../widgets/murkot_action_pills.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/report_sheet.dart';
import '../services/analytics_service.dart';
import 'chat_screen.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({
    super.key,
    required this.listingsService,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    required this.authService,
  });

  final ListingsService listingsService;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final AuthService authService;

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.listingsService.refresh();
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
    widget.listingsService.clearFilters();
  }

  Future<void> _openFiltersSheet(BuildContext context) async {
    final service = widget.listingsService;
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
                        strings.listingsFilters,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.listingTypeLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(strings.listingFilterAll),
                            selected: service.typeFilter == null,
                            onSelected: (_) => service.setTypeFilter(null),
                          ),
                          for (final type in ListingType.values)
                            FilterChip(
                              label: Text(listingTypeLabel(strings, type)),
                              selected: service.typeFilter == type,
                              onSelected: (on) =>
                                  service.setTypeFilter(on ? type : null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.listingCompensationLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(strings.listingFilterCompensationAll),
                            selected: service.compensationFilter == null,
                            onSelected: (_) =>
                                service.setCompensationFilter(null),
                          ),
                          for (final comp in ListingCompensation.values)
                            FilterChip(
                              label: Text(compensationLabel(strings, comp)),
                              selected: service.compensationFilter == comp,
                              onSelected: (on) => service
                                  .setCompensationFilter(on ? comp : null),
                            ),
                        ],
                      ),
                      if (service.availableCities.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          strings.cityLabel,
                          style: theme.textTheme.labelLarge,
                        ),
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
                      if (service.availableSkills.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          strings.skillsLabel,
                          style: theme.textTheme.labelLarge,
                        ),
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
                            child: Text(strings.listingsFiltersDone),
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
    if (boardCreateIntent.value != BoardCreateIntent.listing) return;
    boardCreateIntent.value = BoardCreateIntent.none;
    if (!mounted) return;
    _create();
  }

  Future<void> _respond(Listing listing) async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final strings = context.strings;
    final existing = widget.listingsService.myResponseFor(listing.id);
    if (existing != null) {
      await _openResponseChat(listing);
      return;
    }

    final preview = strings.listingRespondPrefill(listing.title);
    final confirmed = await showAirdropContactSheet(
      context: context,
      recipient: listing.author,
      subjectTitle: listing.title,
      previewText: preview,
    );
    if (!confirmed || !mounted) return;

    try {
      final conversation =
          await widget.chatService.openDirectChat(listing.author);
      await widget.chatService.sendMessage(
        conversationId: conversation.id,
        type: MessageType.text,
        content: preview,
      );
      await widget.listingsService.recordResponse(
        listingId: listing.id,
        conversationId: conversation.id,
        note: preview,
      );
      await AnalyticsService.instance.track('listing_respond', {
        'listing_id': listing.id,
      });
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

  Future<void> _openResponseChat(Listing listing) async {
    final strings = context.strings;
    try {
      final conversation =
          await widget.chatService.openDirectChat(listing.author);
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

  Future<void> _showIncomingResponses(Listing listing) async {
    final service = widget.listingsService;
    final strings = context.strings;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final responses = service.incomingResponses(listing.id);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.listingResponsesTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (responses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          strings.listingResponsesEmpty,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: responses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final r = responses[index];
                            return ListTile(
                              leading: GestureDetector(
                                onTap: r.responderLogin == null ? null : () {
                                  // Quick profile preview
                                  final login = r.responderLogin!;
                                  showDialog<void>(context: context, builder: (_) => Dialog(child: Padding(padding: const EdgeInsets.all(24), child: Text('@$login'))));
                                },
                                child: AvatarDisplay(
                                  name: r.responderLogin ?? '?',
                                  avatarPath: r.responderAvatarUrl,
                                  avatarEmoji: r.responderEmoji,
                                  radius: 20,
                                ),
                              ),
                              title: GestureDetector(
                                onTap: r.responderLogin == null ? null : () {},
                                child: Text(r.responderLogin ?? '?', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              subtitle: Text(_responseStatusLabel(strings, r.status)),
                              trailing: r.status == ListingResponseStatus.inChat ||
                                      r.status == ListingResponseStatus.pending
                                  ? Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          tooltip: strings.listingResponseAccept,
                                          onPressed: () async {
                                            await service.setResponseStatus(
                                              responseId: r.id,
                                              status:
                                                  ListingResponseStatus.accepted,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: strings.listingResponseReject,
                                          onPressed: () async {
                                            await service.setResponseStatus(
                                              responseId: r.id,
                                              status:
                                                  ListingResponseStatus.rejected,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _hide(Listing listing) async {
    final error = await widget.listingsService.hideListing(listing.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? context.strings.hideListingDone),
      ),
    );
  }

  Future<void> _report(Listing listing) async {
    await showReportSheet(
      context: context,
      targetType: 'listing',
      targetId: listing.id,
      targetLabel: listing.title,
    );
  }

  Future<void> _delete(Listing listing) async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.listingDelete,
      message: strings.listingDeleteConfirm,
      confirmLabel: strings.deleteAction,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final error = await widget.listingsService.deleteListing(listing.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? strings.listingDeleted)),
    );
  }

  Future<void> _create() async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final result = await showListingEditorSheet(
      context: context,
      listingsService: widget.listingsService,
    );
    if (result == null || !mounted) return;
    final strings = context.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isNew ? strings.listingPublished : strings.listingUpdated,
        ),
      ),
    );
    if (result.isNew) {
      await _maybeSyncDevStatus(result);
    }
  }

  Future<void> _edit(Listing listing) async {
    final result = await showListingEditorSheet(
      context: context,
      listingsService: widget.listingsService,
      existing: listing,
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.listingUpdated)),
      );
    }
  }

  Future<void> _maybeSyncDevStatus(ListingSheetResult result) async {
    final user = widget.authService.currentUser;
    if (user == null || !mounted) return;

    final desired = switch (result.type) {
      ListingType.lookingForTeam => DevStatus.lookingForTeam,
      ListingType.lookingForMembers => DevStatus.lookingForMembers,
    };
    if (user.devStatus == desired) return;

    final strings = context.strings;
    final statusLabel = devStatusLabel(strings, desired);
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.syncDevStatusTitle,
      message: strings.syncDevStatusMessage(statusLabel),
      confirmLabel: strings.syncDevStatusConfirm,
    );
    if (confirmed != true || !mounted) return;

    final mergedSkills = <String>[
      ...user.skills,
      for (final skill in result.skills)
        if (!user.skills.any((s) => s.toLowerCase() == skill.toLowerCase()))
          skill,
    ];

    final error = await widget.authService.updateDeveloperCard(
      devStatus: desired,
      skills: mergedSkills,
      experienceLevel: user.experienceLevel,
      githubUrl: user.githubUrl,
      portfolioUrl: user.portfolioUrl,
      city: user.city,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? strings.syncDevStatusDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final service = widget.listingsService;

    return ListenableBuilder(
      listenable: Listenable.merge([service, widget.blacklistService]),
      builder: (context, _) {
        final listings = service.listings
            .where((l) => !widget.blacklistService.isBlocked(l.author.login))
            .toList();

        return Column(
          children: [
            _ListingsToolbar(
              service: service,
              searchController: _searchController,
              onClearFilters: _clearFilters,
              onOpenFilters: () => _openFiltersSheet(context),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: service.error != null
                  ? _ErrorState(onRetry: service.refresh)
                  : service.isLoading && listings.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : listings.isEmpty
                          ? _EmptyState(
                              text: service.hasActiveFilters
                                  ? strings.listingsFilterEmpty
                                  : strings.listingsEmpty,
                              actionLabel: service.hasActiveFilters
                                  ? strings.clearFilters
                                  : strings.listingsEmptyAction,
                              onAction: service.hasActiveFilters
                                  ? _clearFilters
                                  : _create,
                            )
                          : RefreshIndicator(
                              onRefresh: service.refresh,
                              child: ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                itemCount: listings.length,
                                itemBuilder: (context, index) {
                                  final listing = listings[index];
                                  final mine = service.isMine(listing);
                                  return _ListingCard(
                                    listing: listing,
                                    isMine: mine,
                                    myResponse: service.myResponseFor(listing.id),
                                    incomingCount:
                                        service.incomingResponseCount(listing.id),
                                    onRespond: () => _respond(listing),
                                    onOpenResponses: mine
                                        ? () => _showIncomingResponses(listing)
                                        : null,
                                    onEdit: () => _edit(listing),
                                    onDelete: () => _delete(listing),
                                    onHide: () => _hide(listing),
                                    onReport: () => _report(listing),
                                  );
                                },
                              ),
                            ),
            ),
            MurkotActionPillsRow(
              pills: [
                MurkotActionPill(
                  icon: Icons.add,
                  label: strings.listingCreate,
                  onPressed: _create,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String listingTypeLabel(AppStrings strings, ListingType type) {
  switch (type) {
    case ListingType.lookingForTeam:
      return strings.devStatusLookingForTeam;
    case ListingType.lookingForMembers:
      return strings.devStatusLookingForMembers;
  }
}

String _responseStatusLabel(AppStrings strings, ListingResponseStatus status) {
  return switch (status) {
    ListingResponseStatus.accepted => strings.listingResponseAccepted,
    ListingResponseStatus.rejected => strings.listingResponseRejected,
    ListingResponseStatus.withdrawn => strings.listingResponded,
    ListingResponseStatus.pending ||
    ListingResponseStatus.inChat =>
      strings.listingResponseInChat,
  };
}

String compensationLabel(AppStrings strings, ListingCompensation compensation) {
  switch (compensation) {
    case ListingCompensation.paid:
      return strings.compensationPaid;
    case ListingCompensation.equity:
      return strings.compensationEquity;
    case ListingCompensation.petProject:
      return strings.compensationPetProject;
  }
}

Color listingTypeColor(ListingType type) {
  switch (type) {
    case ListingType.lookingForTeam:
      return Colors.green.shade600;
    case ListingType.lookingForMembers:
      return Colors.blue.shade600;
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

class _ListingsToolbar extends StatefulWidget {
  const _ListingsToolbar({
    required this.service,
    required this.searchController,
    required this.onClearFilters,
    required this.onOpenFilters,
  });

  final ListingsService service;
  final TextEditingController searchController;
  final VoidCallback onClearFilters;
  final VoidCallback onOpenFilters;

  @override
  State<_ListingsToolbar> createState() => _ListingsToolbarState();
}

class _ListingsToolbarState extends State<_ListingsToolbar> {
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
                hintText: strings.listingsSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: widget.searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: strings.clearFilters,
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
              tooltip: strings.listingsFilters,
              onPressed: widget.onOpenFilters,
              icon: Icon(
                filterCount > 0
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                color: filterCount > 0 ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          PopupMenuButton<ListingSort>(
            tooltip: service.sort == ListingSort.relevance
                ? strings.listingsSortRelevance
                : strings.listingsSortNewest,
            onSelected: service.setSort,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ListingSort.newest,
                child: Text(strings.listingsSortNewest),
              ),
              PopupMenuItem(
                value: ListingSort.relevance,
                enabled: hasQuery,
                child: Text(strings.listingsSortRelevance),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.sort,
                color: service.sort == ListingSort.relevance
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
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.listingLoadFailed,
            style: TextStyle(color: Colors.grey.shade600),
          ),
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

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.isMine,
    required this.myResponse,
    required this.incomingCount,
    required this.onRespond,
    required this.onEdit,
    required this.onDelete,
    required this.onHide,
    required this.onReport,
    this.onOpenResponses,
  });

  final Listing listing;
  final bool isMine;
  final ListingResponse? myResponse;
  final int incomingCount;
  final VoidCallback onRespond;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final VoidCallback? onOpenResponses;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final typeColor = listingTypeColor(listing.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: listing.author.avatarUrl == null
                      ? null
                      : () {
                          final url = listing.author.avatarUrl!;
                          if (url.startsWith('http')) {
                            // Show full avatar — profile navigation is via action buttons.
                            showDialog<void>(
                              context: context,
                              builder: (_) => Dialog(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(url, fit: BoxFit.contain),
                                ),
                              ),
                            );
                          }
                        },
                  child: AvatarDisplay(
                    name: listing.author.login,
                    avatarPath: listing.author.avatarUrl,
                    avatarEmoji: listing.author.avatarEmoji,
                    radius: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.author.login,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (listing.author.city != null &&
                              listing.author.city!.isNotEmpty)
                            listing.author.city!,
                          _relativeTime(strings, listing.createdAt),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'hide':
                        onHide();
                      case 'report':
                        onReport();
                      case 'edit':
                        onEdit();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isMine) ...[
                      PopupMenuItem(
                        value: 'hide',
                        child: Text(strings.hideListing),
                      ),
                      PopupMenuItem(
                        value: 'report',
                        child: Text(strings.reportTitle),
                      ),
                    ],
                    if (isMine) ...[
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(strings.listingEditAction),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(strings.deleteAction),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (isMine) ...[
              const SizedBox(height: 6),
              Text(
                strings.listingMineBadge,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (!isMine && myResponse != null) ...[
              const SizedBox(height: 6),
              Text(
                '${strings.listingResponded} · ${_responseStatusLabel(strings, myResponse!.status)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isMine && incomingCount > 0) ...[
              const SizedBox(height: 6),
              ActionChip(
                avatar: const Icon(Icons.inbox_outlined, size: 16),
                label: Text(strings.listingResponsesCount(incomingCount)),
                onPressed: onOpenResponses,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: typeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    listingTypeLabel(strings, listing.type),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (listing.compensation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      compensationLabel(strings, listing.compensation!),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              listing.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (listing.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                listing.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (listing.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in listing.skills)
                    Chip(
                      label: Text(skill),
                      labelStyle: theme.textTheme.bodySmall,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: isMine
                  ? Wrap(
                      spacing: 4,
                      children: [
                        if (incomingCount > 0)
                          TextButton.icon(
                            onPressed: onOpenResponses,
                            icon: const Icon(Icons.inbox_outlined, size: 18),
                            label: Text(
                              strings.listingResponsesCount(incomingCount),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(strings.listingEditAction),
                        ),
                        TextButton.icon(
                          onPressed: onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(strings.deleteAction),
                        ),
                      ],
                    )
                  : FilledButton.tonalIcon(
                      onPressed: onRespond,
                      icon: Icon(
                        myResponse == null
                            ? Icons.chat_bubble_outline
                            : Icons.forum_outlined,
                        size: 18,
                      ),
                      label: Text(
                        myResponse == null
                            ? strings.listingRespond
                            : strings.listingOpenChat,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingSheetResult {
  const ListingSheetResult({
    required this.isNew,
    required this.type,
    required this.skills,
  });

  final bool isNew;
  final ListingType type;
  final List<String> skills;
}

/// Opens the listing editor; returns a result when saved.
Future<ListingSheetResult?> showListingEditorSheet({
  required BuildContext context,
  required ListingsService listingsService,
  Listing? existing,
}) {
  return showModalBottomSheet<ListingSheetResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ListingEditorSheet(
      listingsService: listingsService,
      existing: existing,
    ),
  );
}

class _ListingEditorSheet extends StatefulWidget {
  const _ListingEditorSheet({
    required this.listingsService,
    this.existing,
  });

  final ListingsService listingsService;
  final Listing? existing;

  @override
  State<_ListingEditorSheet> createState() => _ListingEditorSheetState();
}

class _ListingEditorSheetState extends State<_ListingEditorSheet> {
  late ListingType _type;
  ListingCompensation? _compensation;
  late final List<String> _skills;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _skillController = TextEditingController();
  bool _saving = false;
  String? _titleError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? ListingType.lookingForTeam;
    _compensation = existing?.compensation;
    _skills = List.of(existing?.skills ?? const <String>[]);
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _addSkill(String raw) {
    final skill = raw.trim();
    if (skill.isEmpty) return;
    final exists = _skills.any((s) => s.toLowerCase() == skill.toLowerCase());
    if (!exists) {
      setState(() => _skills.add(skill));
    }
    _skillController.clear();
  }

  Future<void> _publish() async {
    final strings = context.strings;
    final title = _titleController.text.trim();
    if (title.length < 3) {
      setState(() => _titleError = strings.listingTitleRequired);
      return;
    }

    setState(() {
      _titleError = null;
      _saving = true;
    });

    final existing = widget.existing;
    final error = existing == null
        ? await widget.listingsService.createListing(
            type: _type,
            title: title,
            description: _descriptionController.text.trim(),
            skills: _skills,
            compensation: _compensation,
          )
        : await widget.listingsService.updateListing(
            id: existing.id,
            type: _type,
            title: title,
            description: _descriptionController.text.trim(),
            skills: _skills,
            compensation: _compensation,
          );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.listingSaveFailed)),
        );
      return;
    }
    Navigator.pop(
      context,
      ListingSheetResult(
        isNew: existing == null,
        type: _type,
        skills: List.of(_skills),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final suggestions = kSkillSuggestions
        .where((s) =>
            !_skills.any((added) => added.toLowerCase() == s.toLowerCase()))
        .toList();

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
                _isEdit ? strings.listingEdit : strings.listingNewTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                strings.listingTypeLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in ListingType.values)
                    ChoiceChip(
                      label: Text(listingTypeLabel(strings, type)),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: strings.listingTitleLabel,
                  hintText: strings.listingTitleHint,
                  errorText: _titleError,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: strings.listingDescriptionLabel,
                  hintText: strings.listingDescriptionHint,
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.listingCompensationLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(strings.compensationNotSet),
                    selected: _compensation == null,
                    onSelected: (_) => setState(() => _compensation = null),
                  ),
                  for (final comp in ListingCompensation.values)
                    ChoiceChip(
                      label: Text(compensationLabel(strings, comp)),
                      selected: _compensation == comp,
                      onSelected: (_) => setState(() => _compensation = comp),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                strings.skillsLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              if (_skills.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in _skills)
                      Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => setState(() => _skills.remove(skill)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _skillController,
                decoration: InputDecoration(
                  hintText: strings.skillAddHint,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addSkill(_skillController.text),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: _addSkill,
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final suggestion in suggestions.take(12))
                      ActionChip(
                        label: Text(suggestion),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _addSkill(suggestion),
                      ),
                  ],
                ),
              ],
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
                    : Text(_isEdit ? strings.save : strings.listingCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
