import 'package:flutter/foundation.dart';

/// Lets nested screens (e.g. the desktop chat nav rail) switch the
/// bottom-navigation tab of [MainScreen] without a direct reference.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);
