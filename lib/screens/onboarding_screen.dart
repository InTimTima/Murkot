import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/board_tab_bus.dart';
import '../utils/main_tab_bus.dart';
import '../widgets/dev_card.dart';
import '../widgets/murkot_decor.dart';

String onboardingPrefsKey(String userId) => 'onboarding_completed_$userId';

String boardWelcomePrefsKey(String userId) => 'board_welcome_pending_$userId';

/// Minimum viable developer card for Match / discovery.
bool hasMinimumDevCard(User user) =>
    user.devStatus != DevStatus.none && user.skills.length >= 2;

bool needsOnboarding(User user, SharedPreferences prefs) {
  if (prefs.getBool(onboardingPrefsKey(user.id)) ?? false) return false;
  return !hasMinimumDevCard(user);
}

Future<void> enterBoardAfterOnboarding(
  SharedPreferences prefs,
  String userId,
) async {
  resetMainTabBus();
  requestBoardTab(0);
  await prefs.setBool(boardWelcomePrefsKey(userId), true);
}

/// Five-step first-run wizard (goal → skills → level → city → links).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.authService,
    required this.prefs,
  });

  final AuthService authService;
  final SharedPreferences prefs;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 5;

  final _pageController = PageController();
  final _skillController = TextEditingController();
  final _cityController = TextEditingController();
  final _githubController = TextEditingController();
  final _portfolioController = TextEditingController();

  int _step = 0;
  DevStatus _devStatus = DevStatus.lookingForTeam;
  ExperienceLevel? _experience;
  final List<String> _skills = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seedFromUser(widget.authService.currentUser);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _seedFromUser(User? user) {
    if (user == null) return;
    if (user.devStatus != DevStatus.none) _devStatus = user.devStatus;
    _experience = user.experienceLevel;
    _skills
      ..clear()
      ..addAll(user.skills);
    _cityController.text = user.city ?? '';
    _githubController.text = user.githubUrl ?? '';
    _portfolioController.text = user.portfolioUrl ?? '';
  }

  Future<void> _bootstrap() async {
    try {
      await widget.authService.reloadOwnProfile();
    } catch (_) {}
    if (!mounted) return;

    final user = widget.authService.currentUser;
    if (user != null && hasMinimumDevCard(user)) {
      await widget.prefs.setBool(onboardingPrefsKey(user.id), true);
      widget.authService.pingListeners();
      return;
    }

    setState(() => _seedFromUser(user));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _skillController.dispose();
    _cityController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    setState(() {
      _step = index;
      _error = null;
    });
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _addSkill(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    final exists = _skills.any((s) => s.toLowerCase() == tag.toLowerCase());
    if (!exists) setState(() => _skills.add(tag));
    _skillController.clear();
  }

  bool get _meetsMinimum =>
      _devStatus != DevStatus.none && _skills.length >= 2;

  Future<void> _finish({bool force = false}) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // Refresh from server first so a session-fallback User cannot wipe a real card.
    try {
      await widget.authService.reloadOwnProfile();
    } catch (_) {}

    if (!mounted) return;
    final user = widget.authService.currentUser;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    // Skip: close the gate without writing a default lookingForTeam card.
    if (force) {
      await widget.prefs.setBool(onboardingPrefsKey(user.id), true);
      await enterBoardAfterOnboarding(widget.prefs, user.id);
      if (!mounted) return;
      setState(() => _saving = false);
      widget.authService.pingListeners();
      return;
    }

    if (!_meetsMinimum) {
      setState(() {
        _saving = false;
        _error = context.strings.onboardingNeedMinimum;
      });
      if (_devStatus == DevStatus.none) {
        await _goTo(0);
      } else if (_skills.length < 2) {
        await _goTo(1);
      }
      return;
    }

    // Server already has a complete card (stale client opened the wizard) —
    // mark done without overwriting.
    if (hasMinimumDevCard(user)) {
      await widget.prefs.setBool(onboardingPrefsKey(user.id), true);
      await enterBoardAfterOnboarding(widget.prefs, user.id);
      if (!mounted) return;
      setState(() => _saving = false);
      widget.authService.pingListeners();
      return;
    }

    final error = await widget.authService.updateDeveloperCard(
      devStatus: _devStatus,
      skills: List.of(_skills),
      experienceLevel: _experience,
      githubUrl: _githubController.text.trim().isEmpty
          ? null
          : _githubController.text.trim(),
      portfolioUrl: _portfolioController.text.trim().isEmpty
          ? null
          : _portfolioController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = context.strings.onboardingSaveFailed;
      });
      return;
    }

    await widget.prefs.setBool(onboardingPrefsKey(user.id), true);
    await enterBoardAfterOnboarding(widget.prefs, user.id);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.authService.pingListeners();
  }

  Future<void> _onSkip() async {
    if (_meetsMinimum) {
      await _finish();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final strings = ctx.strings;
        return AlertDialog(
          title: Text(strings.onboardingSkipTitle),
          content: Text(strings.onboardingSkipMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.onboardingSkipConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await _finish(force: true);
  }

  Future<void> _onPrimary() async {
    if (_step < _stepCount - 1) {
      await _goTo(_step + 1);
      return;
    }
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final stepLabel = (_step + 1).toString().padLeft(2, '0');

    return Scaffold(
      body: MurkotAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      strings.onboardingEyebrow,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _saving ? null : _onSkip,
                      child: Text(strings.onboardingSkip),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (var i = 0; i < _stepCount; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: i <= _step
                                ? MurkotColors.orange
                                : (isLight
                                    ? Colors.black12
                                    : Colors.white24),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stepLabel,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: MurkotColors.orange.withValues(alpha: 0.9),
                      height: 1,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepScaffold(
                      title: strings.onboardingStepGoalTitle,
                      subtitle: strings.onboardingStepGoalSub,
                      child: _GoalPicker(
                        value: _devStatus,
                        onChanged: (v) => setState(() => _devStatus = v),
                      ),
                    ),
                    _StepScaffold(
                      title: strings.onboardingStepSkillsTitle,
                      subtitle: strings.onboardingStepSkillsSub,
                      child: _SkillsPicker(
                        skills: _skills,
                        controller: _skillController,
                        onAdd: _addSkill,
                        onRemove: (tag) =>
                            setState(() => _skills.remove(tag)),
                      ),
                    ),
                    _StepScaffold(
                      title: strings.onboardingStepLevelTitle,
                      subtitle: strings.onboardingStepLevelSub,
                      child: _LevelPicker(
                        value: _experience,
                        onChanged: (v) => setState(() => _experience = v),
                      ),
                    ),
                    _StepScaffold(
                      title: strings.onboardingStepCityTitle,
                      subtitle: strings.onboardingStepCitySub,
                      child: TextField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: strings.cityLabel,
                          hintText: strings.cityHint,
                          prefixIcon: const Icon(Icons.location_city_outlined),
                        ),
                      ),
                    ),
                    _StepScaffold(
                      title: strings.onboardingStepLinksTitle,
                      subtitle: strings.onboardingStepLinksSub,
                      child: Column(
                        children: [
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(
                        onPressed: _saving ? null : () => _goTo(_step - 1),
                        child: Text(strings.onboardingBack),
                      )
                    else
                      const SizedBox(width: 88),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _onPrimary,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 48),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _step == _stepCount - 1
                                  ? strings.onboardingFinish
                                  : strings.onboardingNext,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  const _GoalPicker({required this.value, required this.onChanged});

  final DevStatus value;
  final ValueChanged<DevStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final options = [
      DevStatus.lookingForTeam,
      DevStatus.lookingForMembers,
      DevStatus.openToOffers,
    ];

    return Column(
      children: [
        for (final status in options) ...[
          _OptionTile(
            selected: value == status,
            title: devStatusLabel(strings, status),
            onTap: () => onChanged(status),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LevelPicker extends StatelessWidget {
  const _LevelPicker({required this.value, required this.onChanged});

  final ExperienceLevel? value;
  final ValueChanged<ExperienceLevel?> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final level in ExperienceLevel.values)
          ChoiceChip(
            label: Text(experienceLevelLabel(strings, level)),
            selected: value == level,
            onSelected: (on) => onChanged(on ? level : null),
          ),
      ],
    );
  }
}

class _SkillsPicker extends StatelessWidget {
  const _SkillsPicker({
    required this.skills,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> skills;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final suggestions = kSkillSuggestions
        .where(
          (s) => !skills.any((added) => added.toLowerCase() == s.toLowerCase()),
        )
        .take(14)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (skills.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in skills)
                Chip(
                  label: Text(tag),
                  onDeleted: () => onRemove(tag),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: strings.skillAddHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onAdd(controller.text),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: onAdd,
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  label: Text(suggestion),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAdd(suggestion),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Material(
      color: selected
          ? MurkotColors.orange.withValues(alpha: isLight ? 0.14 : 0.28)
          : (isLight ? Colors.white.withValues(alpha: 0.75) : Colors.white10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? MurkotColors.orange
              : (isLight ? Colors.black12 : Colors.white24),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? MurkotColors.orange
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
