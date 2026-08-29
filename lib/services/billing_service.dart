import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MurkotProduct {
  plusMonthly,
  boostTop,
  boostPin24,
  boostHighlight,
  boostPush,
  hrOffice,
}

class MurkotProductInfo {
  const MurkotProductInfo({
    required this.product,
    required this.titleRu,
    required this.titleEn,
    required this.priceRub,
    required this.descriptionRu,
    required this.descriptionEn,
    required this.icon,
    this.isSubscription = false,
  });

  final MurkotProduct product;
  final String titleRu;
  final String titleEn;
  final int priceRub;
  final String descriptionRu;
  final String descriptionEn;
  final IconData icon;
  final bool isSubscription;

  String title(bool isRu) => isRu ? titleRu : titleEn;
  String description(bool isRu) => isRu ? descriptionRu : descriptionEn;
  String priceLabel(bool isRu) {
    final n = priceRub.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    if (isSubscription) {
      return isRu ? '$n ₽/мес' : '$n RUB/mo';
    }
    return isRu ? '$n ₽' : '$n RUB';
  }
}

const kMurkotCatalog = <MurkotProductInfo>[
  MurkotProductInfo(
    product: MurkotProduct.plusMonthly,
    titleRu: 'Murkot Plus',
    titleEn: 'Murkot Plus',
    priceRub: 399,
    isSubscription: true,
    icon: Icons.auto_awesome,
    descriptionRu:
        'Гиф-аватар, рамки и эффекты, цвет ника, 5 бесплатных подъёмов в топ в сутки, до 15 активных объявлений, кто смотрел профиль и сохранял контакты.',
    descriptionEn:
        'GIF avatar, frames & FX, nick color, 5 free top boosts/day, up to 15 listings, profile viewers & contact saves.',
  ),
  MurkotProductInfo(
    product: MurkotProduct.boostTop,
    titleRu: 'Поднять в топ',
    titleEn: 'Boost to top',
    priceRub: 50,
    icon: Icons.rocket_launch_outlined,
    descriptionRu:
        'Объявление мгновенно перелетает наверх ленты. Его видят все, кто открывает раздел «Объявления».',
    descriptionEn:
        'Listing jumps to the top of the feed for everyone opening Listings.',
  ),
  MurkotProductInfo(
    product: MurkotProduct.boostPin24,
    titleRu: 'Закреп на 24 часа',
    titleEn: 'Pin for 24h',
    priceRub: 150,
    icon: Icons.push_pin_outlined,
    descriptionRu: 'Объявление висит вверху сутки и не опускается.',
    descriptionEn: 'Listing stays pinned at the top for 24 hours.',
  ),
  MurkotProductInfo(
    product: MurkotProduct.boostHighlight,
    titleRu: 'Выделение цветом',
    titleEn: 'Color highlight',
    priceRub: 99,
    icon: Icons.color_lens_outlined,
    descriptionRu:
        'Фон карточки становится ярко-жёлтым или синим — глаз цепляется среди серых.',
    descriptionEn:
        'Card background turns bright yellow or blue so it stands out.',
  ),
  MurkotProductInfo(
    product: MurkotProduct.boostPush,
    titleRu: 'Пуш-уведомление',
    titleEn: 'Push broadcast',
    priceRub: 999,
    icon: Icons.notifications_active_outlined,
    descriptionRu:
        'Объявление рассылается пушем выбранному сегменту (например, Flutter в Москве).',
    descriptionEn:
        'Listing is pushed to a chosen segment (e.g. Flutter devs in Moscow).',
  ),
  MurkotProductInfo(
    product: MurkotProduct.hrOffice,
    titleRu: 'Кабинет HR',
    titleEn: 'HR Office',
    priceRub: 24999,
    isSubscription: true,
    icon: Icons.business_center_outlined,
    descriptionRu:
        'Безлимитный поиск по базе, брендированный профиль компании, Smart-подбор (ИИ), рассылка до 20 кандидатам.',
    descriptionEn:
        'Unlimited talent search, branded company profile, AI smart match, bulk DM up to 20.',
  ),
];

MurkotProductInfo productInfo(MurkotProduct product) =>
    kMurkotCatalog.firstWhere((p) => p.product == product);

class BillingService extends ChangeNotifier {
  BillingService();

  final _client = Supabase.instance.client;

  bool isPlus = false;
  DateTime? plusUntil;
  bool hasHrOffice = false;

  void syncFromProfile({required bool plus, DateTime? until, bool hr = false}) {
    final active = plus && (until == null || until.isAfter(DateTime.now()));
    if (isPlus == active && plusUntil == until && hasHrOffice == hr) return;
    isPlus = active;
    plusUntil = until;
    hasHrOffice = hr;
    notifyListeners();
  }

  /// Stub until YooKassa backend verify is wired. Persists Plus to profile.
  Future<bool> purchase(MurkotProduct product) async {
    debugPrint('billing purchase $product — stub YooKassa');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (product == MurkotProduct.plusMonthly) {
      final until = DateTime.now().add(const Duration(days: 30));
      try {
        final uid = _client.auth.currentUser?.id;
        if (uid != null) {
          await _client.from('profiles').update({
            'is_plus': true,
            'plus_until': until.toUtc().toIso8601String(),
          }).eq('id', uid);
        }
      } catch (e) {
        debugPrint('persist plus failed: $e');
      }
      isPlus = true;
      plusUntil = until;
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

  bool get canBoostFree => isPlus;
  int get maxListings => isPlus ? 15 : 3;
  int get freeBoostsPerDay => isPlus ? 5 : 1;

  bool get canUseGifAvatar => isPlus;
  bool get canUseFrame => isPlus;
  bool get canUseNickColor => isPlus;
  List<String> get availableFrames =>
      isPlus
          ? const ['stars', 'sparkle', 'wave', 'dots', 'citrus', 'drops']
          : const [];
}

class HrOfficeService extends ChangeNotifier {
  bool hasHrOffice = false;
}
