import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'dev_status_badge.dart';

String devStatusLabel(AppStrings strings, DevStatus status) {
  switch (status) {
    case DevStatus.none:
      return strings.devStatusNone;
    case DevStatus.lookingForTeam:
      return strings.devStatusLookingForTeam;
    case DevStatus.lookingForMembers:
      return strings.devStatusLookingForMembers;
    case DevStatus.openToOffers:
      return strings.devStatusOpenToOffers;
  }
}

String experienceLevelLabel(AppStrings strings, ExperienceLevel level) {
  switch (level) {
    case ExperienceLevel.junior:
      return strings.levelJunior;
    case ExperienceLevel.middle:
      return strings.levelMiddle;
    case ExperienceLevel.senior:
      return strings.levelSenior;
    case ExperienceLevel.lead:
      return strings.levelLead;
  }
}

Color devStatusColor(DevStatus status, ColorScheme scheme) {
  switch (status) {
    case DevStatus.none:
      return scheme.outline;
    case DevStatus.lookingForTeam:
      return Colors.green.shade600;
    case DevStatus.lookingForMembers:
      return Colors.blue.shade600;
    case DevStatus.openToOffers:
      return Colors.orange.shade700;
  }
}

/// Read-only developer card used on own and stranger profile screens.
class DevCardView extends StatelessWidget {
  const DevCardView({
    super.key,
    required this.user,
    this.showPlaceholderWhenEmpty = true,
  });

  final User user;
  final bool showPlaceholderWhenEmpty;

  static bool hasContent(User user) =>
      user.devStatus != DevStatus.none ||
      user.skills.isNotEmpty ||
      user.experienceLevel != null ||
      (user.githubUrl?.isNotEmpty ?? false) ||
      (user.portfolioUrl?.isNotEmpty ?? false) ||
      (user.city?.isNotEmpty ?? false);

  bool get _isEmpty => !hasContent(user);

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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    if (_isEmpty) {
      if (!showPlaceholderWhenEmpty) return const SizedBox.shrink();
      return Text(
        strings.devCardSubtitle,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }

    final github = user.githubUrl?.trim() ?? '';
    final portfolio = user.portfolioUrl?.trim() ?? '';
    final city = user.city?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.devStatus != DevStatus.none)
          DevStatusBadge(status: user.devStatus),
        if (user.experienceLevel != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.military_tech_outlined,
                  size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                '${strings.experienceLabel}: '
                '${experienceLevelLabel(strings, user.experienceLevel!)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
        if (city.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_outlined,
                  size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(child: Text(city, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ],
        if (user.skills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skill in user.skills)
                Chip(
                  label: Text(skill),
                  labelStyle: theme.textTheme.bodySmall,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
        if (github.isNotEmpty || portfolio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (github.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.code, size: 16),
                  label: Text(strings.githubLabel),
                  onPressed: () => _openLink(github),
                ),
              if (portfolio.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.link, size: 16),
                  label: Text(strings.portfolioLabel),
                  onPressed: () => _openLink(portfolio),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Frequently used stacks offered as quick-add suggestions.
const kSkillSuggestions = [
  'Flutter',
  'Dart',
  'Python',
  'JavaScript',
  'TypeScript',
  'React',
  'Node.js',
  'Go',
  'Java',
  'Kotlin',
  'Swift',
  'C#',
  'C++',
  'PHP',
  'SQL',
  'DevOps',
  'QA',
  'UI/UX',
  'ML',
  'Android',
  'iOS',
];

/// Opens the developer card editor; returns true if the card was saved.
Future<bool?> showDevCardEditSheet({
  required BuildContext context,
  required AuthService authService,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _DevCardEditSheet(authService: authService),
  );
}

class _DevCardEditSheet extends StatefulWidget {
  const _DevCardEditSheet({required this.authService});

  final AuthService authService;

  @override
  State<_DevCardEditSheet> createState() => _DevCardEditSheetState();
}

class _DevCardEditSheetState extends State<_DevCardEditSheet> {
  late DevStatus _devStatus;
  late List<String> _skills;
  ExperienceLevel? _level;
  late final TextEditingController _skillController;
  late final TextEditingController _githubController;
  late final TextEditingController _portfolioController;
  late final TextEditingController _cityController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.authService.currentUser!;
    _devStatus = user.devStatus;
    _skills = List.of(user.skills);
    _level = user.experienceLevel;
    _skillController = TextEditingController();
    _githubController = TextEditingController(text: user.githubUrl ?? '');
    _portfolioController = TextEditingController(text: user.portfolioUrl ?? '');
    _cityController = TextEditingController(text: user.city ?? '');
  }

  @override
  void dispose() {
    _skillController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _addSkill(String raw) {
    final skill = raw.trim();
    if (skill.isEmpty) return;
    final exists =
        _skills.any((s) => s.toLowerCase() == skill.toLowerCase());
    if (!exists) {
      setState(() => _skills.add(skill));
    }
    _skillController.clear();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await widget.authService.updateDeveloperCard(
      devStatus: _devStatus,
      skills: _skills,
      experienceLevel: _level,
      githubUrl: _githubController.text.trim(),
      portfolioUrl: _portfolioController.text.trim(),
      city: _cityController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context, true);
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
                strings.devCardTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(strings.devStatusLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in DevStatus.values)
                    ChoiceChip(
                      label: Text(devStatusLabel(strings, status)),
                      selected: _devStatus == status,
                      onSelected: (_) => setState(() => _devStatus = status),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(strings.experienceLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(strings.levelNotSet),
                    selected: _level == null,
                    onSelected: (_) => setState(() => _level = null),
                  ),
                  for (final level in ExperienceLevel.values)
                    ChoiceChip(
                      label: Text(experienceLevelLabel(strings, level)),
                      selected: _level == level,
                      onSelected: (_) => setState(() => _level = level),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(strings.skillsLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
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
                        onDeleted: () =>
                            setState(() => _skills.remove(skill)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _skillController,
                decoration: InputDecoration(
                  hintText: strings.skillAddHint,
                  helperText: strings.skillsHint,
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
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: strings.cityLabel,
                  hintText: strings.cityHint,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _githubController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: strings.githubLabel,
                  hintText: strings.linkHint,
                  prefixIcon: const Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portfolioController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: strings.portfolioLabel,
                  hintText: strings.linkHint,
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
