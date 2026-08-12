import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/listing.dart';
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
import '../widgets/murkot_decor.dart';
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
    super.dispose();
  }

  void _onCreateIntent() {
    if (boardCreateIntent.value != BoardCreateIntent.listing) return;
    boardCreateIntent.value = BoardCreateIntent.none;
    if (!mounted) return;
    _create();
  }

  Future<void> _respond(Listing listing) async {
    final strings = context.strings;
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
            initialComposerText: preview,
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
    final theme = Theme.of(context);
    final service = widget.listingsService;

    return ListenableBuilder(
      listenable: Listenable.merge([service, widget.blacklistService]),
      builder: (context, _) {
        final listings = service.listings
            .where((l) => !widget.blacklistService.isBlocked(l.author.login))
            .toList();
        final skills = service.availableSkills;

        return Column(
          children: [
            _TypeFilterBar(service: service),
            if (skills.isNotEmpty) _SkillFilterBar(service: service),
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
                                  : null,
                              onAction: service.hasActiveFilters
                                  ? service.clearFilters
                                  : null,
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
                                  return _ListingCard(
                                    listing: listing,
                                    isMine: service.isMine(listing),
                                    onRespond: () => _respond(listing),
                                    onEdit: () => _edit(listing),
                                    onDelete: () => _delete(listing),
                                  );
                                },
                              ),
                            ),
            ),
            Material(
              elevation: 4,
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
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          strings.listingCreate,
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

String listingTypeLabel(AppStrings strings, ListingType type) {
  switch (type) {
    case ListingType.lookingForTeam:
      return strings.devStatusLookingForTeam;
    case ListingType.lookingForMembers:
      return strings.devStatusLookingForMembers;
  }
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

class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.service});

  final ListingsService service;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(strings.listingFilterAll),
              selected: service.typeFilter == null,
              onSelected: (_) => service.setTypeFilter(null),
            ),
            const SizedBox(width: 8),
            for (final type in ListingType.values) ...[
              ChoiceChip(
                label: Text(listingTypeLabel(strings, type)),
                selected: service.typeFilter == type,
                onSelected: (_) => service.setTypeFilter(
                  service.typeFilter == type ? null : type,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillFilterBar extends StatelessWidget {
  const _SkillFilterBar({required this.service});

  final ListingsService service;

  @override
  Widget build(BuildContext context) {
    final selected = service.skillFilter;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final skill in service.availableSkills) ...[
              FilterChip(
                label: Text(skill),
                visualDensity: VisualDensity.compact,
                selected: selected != null &&
                    selected.toLowerCase() == skill.toLowerCase(),
                onSelected: (on) =>
                    service.setSkillFilter(on ? skill : null),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
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
    required this.onRespond,
    required this.onEdit,
    required this.onDelete,
  });

  final Listing listing;
  final bool isMine;
  final VoidCallback onRespond;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                AvatarDisplay(
                  name: listing.author.login,
                  avatarPath: listing.author.avatarUrl,
                  avatarEmoji: listing.author.avatarEmoji,
                  radius: 18,
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
                        _relativeTime(strings, listing.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      strings.listingMineBadge,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
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
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(strings.listingRespond),
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
