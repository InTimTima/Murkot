import 'package:flutter/foundation.dart';

import '../models/conversation.dart';

/// Bottom nav of [MainScreen]:
/// 0 = Board, 1 = Messenger, 2 = Profile.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);

/// Filter inside the Messenger hub (DMs / groups / channels).
final ValueNotifier<ConversationType> messengerFilter =
    ValueNotifier<ConversationType>(ConversationType.direct);

abstract final class MainTabs {
  static const board = 0;
  static const chats = 1;
  static const profile = 2;
}

/// Call on logout so the next session does not inherit tab state.
void resetMainTabBus() {
  mainTabIndex.value = MainTabs.board;
  messengerFilter.value = ConversationType.direct;
}
