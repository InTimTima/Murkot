import 'package:flutter/foundation.dart';

/// Board sub-tab: 0 listings, 1 projects, 2 match, 3 communities.
final ValueNotifier<int> boardTabIndex = ValueNotifier<int>(0);

/// One-shot create intents consumed by board child screens.
enum BoardCreateIntent { none, listing, project }

final ValueNotifier<BoardCreateIntent> boardCreateIntent =
    ValueNotifier<BoardCreateIntent>(BoardCreateIntent.none);

void requestBoardTab(int index) {
  boardTabIndex.value = index.clamp(0, 3);
}

void requestBoardCreate(BoardCreateIntent intent) {
  // Force a value change so listeners fire even if the same intent was pending.
  if (boardCreateIntent.value == intent) {
    boardCreateIntent.value = BoardCreateIntent.none;
  }
  boardCreateIntent.value = intent;
}

/// Call on logout so the next session does not inherit board state.
void resetBoardTabBus() {
  boardTabIndex.value = 0;
  boardCreateIntent.value = BoardCreateIntent.none;
}
