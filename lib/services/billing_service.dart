import 'package:flutter/foundation.dart';

enum MurkotProduct {
  plusMonthly, // 399 rub
  boostTop, // 50
  boostPin24, // 150
  boostHighlight, // 99
  boostPush, // 999
  hrOffice, // 24999
}

class BillingService extends ChangeNotifier {
  bool isPlus = false;
  DateTime? plusUntil;
  bool hasHrOffice = false;
  int boostsTopLeft = 0;

  // Stub: integrate YooKassa SDK / backend verify
  Future<bool> purchase(MurkotProduct product) async {
    debugPrint('billing purchase $product — stub, integrate YooKassa');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (product == MurkotProduct.plusMonthly) {
      isPlus = true;
      plusUntil = DateTime.now().add(const Duration(days: 30));
      notifyListeners();
      return true;
    }
    if (product == MurkotProduct.hrOffice) {
      hasHrOffice = true;
      notifyListeners();
      return true;
    }
    return true;
  }

  bool get canBoostFree => isPlus; // 5/day vs 1/day handled server-side
  int get maxListings => isPlus ? 15 : 3;
  int get freeBoostsPerDay => isPlus ? 5 : 1;

  // Cosmetic entitlements for Plus
  bool get canUseGifAvatar => isPlus;
  bool get canUseFrame => isPlus;
  bool get canUseNickColor => isPlus;
  List<String> get availableFrames => isPlus ? ['stars','sparkle','wave','dots','citrus','drops'] : [];
}

class HrOfficeService extends ChangeNotifier {
  bool hasHrOffice = false;
  // Unlimited search, branded company profile, AI smart filter, bulk DM up to 20
}
