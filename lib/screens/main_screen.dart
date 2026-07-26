import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'profile_screen.dart';
import 'chats_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.authService,
    required this.settingsService,
  });

  final AuthService authService;
  final SettingsService settingsService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    final pages = [
      const ChatsScreen(),
      ProfileScreen(
        authService: widget.authService,
        settingsService: widget.settingsService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: strings.chats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.profile,
          ),
        ],
      ),
    );
  }
}
