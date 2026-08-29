import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/plus_cosmetics.dart';
import '../models/user.dart';
import '../models/user_preview.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/people_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../widgets/avatar_display.dart';
import '../widgets/dev_card.dart';
import '../widgets/dev_status_badge.dart';
import '../widgets/guest_gate.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'chat_screen.dart';
import 'public_profile_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({
    super.key,
    required this.peopleService,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final PeopleService peopleService;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.peopleService.searchQuery;
    widget.peopleService.refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    widget.peopleService.setSearchQuery(value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      widget.peopleService.applySearchAndRefresh();
    });
  }

  Future<void> _openFiltersSheet() async {
    final service = widget.peopleService;
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
                        strings.peopleFilters,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(strings.devStatusLabel,
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(strings.peopleFilterStatusAll),
                            selected: service.statusFilter == null,
                            onSelected: (_) => service.setStatusFilter(null),
                          ),
                          for (final status in const [
                            DevStatus.lookingForTeam,
                            DevStatus.lookingForMembers,
                            DevStatus.openToOffers,
                          ])
                            FilterChip(
                              label: Text(devStatusLabel(strings, status)),
                              selected: service.statusFilter == status,
                              onSelected: (on) => service.setStatusFilter(
                                on ? status : null,
                              ),
                            ),
                        ],
                      ),
                      if (service.availableSkills.isNotEmpty) ...[
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(strings.listingsFiltersDone),
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

  Future<void> _openProfile(User user) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          login: user.login,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          presenceService: widget.presenceService,
          currentUserLogin: widget.currentUserLogin,
          settingsService: widget.settingsService,
        ),
      ),
    );
  }

  Future<void> _message(User user) async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final strings = context.strings;
    try {
      final conversation = await widget.chatService.openDirectChat(
        UserPreview(
          id: user.id,
          login: user.login,
          status: user.status,
          avatarEmoji: user.avatarEmoji,
          avatarUrl: user.avatarPath,
          city: user.city,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.peopleService,
      builder: (context, _) {
        final service = widget.peopleService;
        final people = service.people
            .where((u) => !widget.blacklistService.isBlocked(u.login))
            .toList();

        return Column(
          children: [
            _PeopleToolbar(
              service: service,
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onClearFilters: () {
                _searchController.clear();
                service.clearFilters();
              },
              onOpenFilters: _openFiltersSheet,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: service.refresh,
                child: service.isLoading && people.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: MurkotLoader(size: 44)),
                        ],
                      )
                    : service.error != null && people.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              Text(
                                strings.peopleLoadFailed,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: FilledButton(
                                  onPressed: service.refresh,
                                  child: Text(strings.retry),
                                ),
                              ),
                            ],
                          )
                        : people.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(24),
                                children: [
                                  const SizedBox(height: 48),
                                  Text(
                                    service.hasActiveFilters
                                        ? strings.peopleEmptyFiltered
                                        : strings.peopleEmpty,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  if (service.hasActiveFilters) ...[
                                    const SizedBox(height: 12),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          service.clearFilters();
                                        },
                                        child: Text(strings.clearFilters),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                                itemCount: people.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final user = people[index];
                                  return _PersonCard(
                                    user: user,
                                    sharedSkills:
                                        service.sharedSkillsFor(user.id),
                                    onOpen: () => _openProfile(user),
                                    onMessage: () => _message(user),
                                  );
                                },
                              ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PeopleToolbar extends StatelessWidget {
  const _PeopleToolbar({
    required this.service,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearFilters,
    required this.onOpenFilters,
  });

  final PeopleService service;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final filterCount = service.activeFilterCount;
    final hasQuery = searchController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => service.applySearchAndRefresh(),
              decoration: InputDecoration(
                isDense: true,
                hintText: strings.peopleSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
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
              tooltip: strings.peopleFilters,
              onPressed: onOpenFilters,
              icon: Icon(
                Icons.tune,
                color: filterCount > 0 ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          PopupMenuButton<PeopleSort>(
            tooltip: service.sort == PeopleSort.login
                ? strings.peopleSortLogin
                : strings.peopleSortShared,
            onSelected: service.setSort,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: PeopleSort.sharedSkills,
                child: Text(strings.peopleSortShared),
              ),
              PopupMenuItem(
                value: PeopleSort.login,
                child: Text(strings.peopleSortLogin),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
          if (service.hasActiveFilters)
            IconButton(
              tooltip: strings.clearFilters,
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.user,
    required this.sharedSkills,
    required this.onOpen,
    required this.onMessage,
  });

  final User user;
  final int sharedSkills;
  final VoidCallback onOpen;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final city = user.city?.trim();

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarDisplay(
                    name: user.login,
                    avatarPath: user.avatarPath,
                    avatarEmoji: user.avatarEmoji,
                    radius: 24,
                    frame: user.avatarFrame,
                    showPlusBadge: user.isPlus,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.login,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: nickColorFromId(user.nickColorId),
                          ),
                        ),
                        if (city != null && city.isNotEmpty)
                          Text(
                            city,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.matchOpenChat,
                    onPressed: onMessage,
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                ],
              ),
              if (user.devStatus != DevStatus.none) ...[
                const SizedBox(height: 8),
                DevStatusBadge(status: user.devStatus),
              ],
              if (user.status.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  user.status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (user.skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in user.skills.take(8))
                      Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                  ],
                ),
              ],
              if (sharedSkills > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${strings.matchSharedSkills}: $sharedSkills',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (DevCardView.hasContent(user) &&
                  (user.experienceLevel != null ||
                      (user.githubUrl?.isNotEmpty ?? false))) ...[
                const SizedBox(height: 8),
                Text(
                  strings.peopleOpenProfile,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
