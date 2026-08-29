import 'package:flutter/material.dart';

import '../config/brand_theme.dart';

/// Avatar ring styles unlocked by Murkot Plus.
enum AvatarFrameId {
  none('none'),
  stars('stars'),
  sparkle('sparkle'),
  wave('wave'),
  dots('dots'),
  citrus('citrus'),
  drops('drops');

  const AvatarFrameId(this.dbValue);
  final String dbValue;

  static AvatarFrameId fromDb(String? value) => AvatarFrameId.values.firstWhere(
        (f) => f.dbValue == value,
        orElse: () => AvatarFrameId.none,
      );

  String title(bool isRu) => switch (this) {
        AvatarFrameId.none => isRu ? 'Без рамки' : 'No frame',
        AvatarFrameId.stars => isRu ? 'Звёзды' : 'Stars',
        AvatarFrameId.sparkle => isRu ? 'Блеск' : 'Sparkle',
        AvatarFrameId.wave => isRu ? 'Волны' : 'Waves',
        AvatarFrameId.dots => isRu ? 'Точки' : 'Dots',
        AvatarFrameId.citrus => isRu ? 'Цитрус' : 'Citrus',
        AvatarFrameId.drops => isRu ? 'Капли' : 'Drops',
      };

  IconData get icon => switch (this) {
        AvatarFrameId.none => Icons.circle_outlined,
        AvatarFrameId.stars => Icons.star_outline,
        AvatarFrameId.sparkle => Icons.auto_awesome,
        AvatarFrameId.wave => Icons.waves,
        AvatarFrameId.dots => Icons.more_horiz,
        AvatarFrameId.citrus => Icons.eco_outlined,
        AvatarFrameId.drops => Icons.water_drop_outlined,
      };
}

class NickColorOption {
  const NickColorOption({
    required this.id,
    required this.color,
    required this.titleRu,
    required this.titleEn,
  });

  final String id;
  final Color color;
  final String titleRu;
  final String titleEn;

  String title(bool isRu) => isRu ? titleRu : titleEn;
}

const kNickColorOptions = <NickColorOption>[
  NickColorOption(
    id: 'orange',
    color: MurkotColors.orange,
    titleRu: 'Апельсин',
    titleEn: 'Orange',
  ),
  NickColorOption(
    id: 'amber',
    color: Color(0xFFE8A317),
    titleRu: 'Янтарь',
    titleEn: 'Amber',
  ),
  NickColorOption(
    id: 'coral',
    color: Color(0xFFE85D4C),
    titleRu: 'Коралл',
    titleEn: 'Coral',
  ),
  NickColorOption(
    id: 'leaf',
    color: MurkotColors.leaf,
    titleRu: 'Листва',
    titleEn: 'Leaf',
  ),
  NickColorOption(
    id: 'sky',
    color: Color(0xFF3B82F6),
    titleRu: 'Небо',
    titleEn: 'Sky',
  ),
  NickColorOption(
    id: 'violet',
    color: Color(0xFF7C3AED),
    titleRu: 'Фиолет',
    titleEn: 'Violet',
  ),
  NickColorOption(
    id: 'rose',
    color: Color(0xFFDB2777),
    titleRu: 'Роза',
    titleEn: 'Rose',
  ),
  NickColorOption(
    id: 'ink',
    color: Color(0xFF1F2937),
    titleRu: 'Чернила',
    titleEn: 'Ink',
  ),
];

Color? nickColorFromId(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final o in kNickColorOptions) {
    if (o.id == id) return o.color;
  }
  // Allow raw hex like #RRGGBB
  final hex = id.replaceFirst('#', '');
  if (hex.length == 6) {
    final value = int.tryParse(hex, radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return null;
}
