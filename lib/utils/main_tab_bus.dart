import 'package:flutter/foundation.dart';

/// Bottom nav of [MainScreen]:
/// 0 = Board, 1 = Chats, 2 = Profile.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);

abstract final class MainTabs {
  static const board = 0;
  static const chats = 1;
  static const profile = 2;
}

/// Call on logout so the next session does not inherit tab state.
void resetMainTabBus() {
  mainTabIndex.value = MainTabs.board;
}
