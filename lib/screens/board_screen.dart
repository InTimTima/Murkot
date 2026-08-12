import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/listings_service.dart';
import '../services/match_service.dart';
import '../services/presence_service.dart';
import '../services/projects_service.dart';
import '../services/settings_service.dart';
import '../utils/board_tab_bus.dart';
import 'communities_screen.dart';
import 'listings_screen.dart';
import 'match_screen.dart';
import 'projects_screen.dart';

/// The "Board" tab: listings, projects, matching and community channels.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.listingsService,
    required this.projectsService,
    required this.matchService,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    required this.authService,
  });

  final ListingsService listingsService;
  final ProjectsService projectsService;
  final MatchService matchService;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final AuthService authService;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Set<int> _builtTabs;

  @override
  void initState() {
    super.initState();
    final initial = boardTabIndex.value.clamp(0, 3);
    _builtTabs = {initial};
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: initial,
    );
    _tabs.addListener(_onTabChanged);
    boardTabIndex.addListener(_onExternalTab);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final index = _tabs.index;
    if (boardTabIndex.value != index) {
      boardTabIndex.value = index;
    }
    if (!_builtTabs.contains(index)) {
      setState(() => _builtTabs.add(index));
    }
  }

  void _onExternalTab() {
    final target = boardTabIndex.value.clamp(0, 3);
    if (!_builtTabs.contains(target)) {
      setState(() => _builtTabs.add(target));
    }
    if (_tabs.index != target) {
      _tabs.animateTo(target);
    }
  }

  @override
  void dispose() {
    boardTabIndex.removeListener(_onExternalTab);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Widget _lazy(int index, Widget child) {
    if (!_builtTabs.contains(index)) {
      return const SizedBox.expand();
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: strings.boardListingsTab),
              Tab(text: strings.boardProjectsTab),
              Tab(text: strings.boardMatchTab),
              Tab(text: strings.boardCommunitiesTab),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _lazy(
                0,
                ListingsScreen(
                  listingsService: widget.listingsService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                  authService: widget.authService,
                ),
              ),
              _lazy(
                1,
                ProjectsScreen(
                  projectsService: widget.projectsService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
              _lazy(
                2,
                MatchScreen(
                  matchService: widget.matchService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                  authService: widget.authService,
                ),
              ),
              _lazy(
                3,
                CommunitiesScreen(
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
