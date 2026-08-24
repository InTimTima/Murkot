class StickerItem {
  const StickerItem({required this.id, required this.glyph, required this.label});

  final String id;
  final String glyph;
  final String label;
}

class StickerPack {
  const StickerPack({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.stickers,
  });

  final String id;
  final String titleRu;
  final String titleEn;
  final List<StickerItem> stickers;

  String title(bool isRu) => isRu ? titleRu : titleEn;
}

const kStickerPacks = <StickerPack>[
  StickerPack(
    id: 'murki',
    titleRu: 'Мурки',
    titleEn: 'Murki',
    stickers: [
      StickerItem(id: 'm1', glyph: '🐱', label: 'hi'),
      StickerItem(id: 'm2', glyph: '😺', label: 'smile'),
      StickerItem(id: 'm3', glyph: '😻', label: 'love'),
      StickerItem(id: 'm4', glyph: '😹', label: 'lol'),
      StickerItem(id: 'm5', glyph: '🙀', label: 'wow'),
      StickerItem(id: 'm6', glyph: '😾', label: 'grumpy'),
      StickerItem(id: 'm7', glyph: '🐈', label: 'walk'),
      StickerItem(id: 'm8', glyph: '🐈‍⬛', label: 'night'),
      StickerItem(id: 'm9', glyph: '🐾', label: 'paws'),
      StickerItem(id: 'm10', glyph: '🧶', label: 'yarn'),
      StickerItem(id: 'm11', glyph: '🐟', label: 'fish'),
      StickerItem(id: 'm12', glyph: '🥛', label: 'milk'),
    ],
  ),
  StickerPack(
    id: 'sok',
    titleRu: 'Сок',
    titleEn: 'Juice',
    stickers: [
      StickerItem(id: 's1', glyph: '🍊', label: 'orange'),
      StickerItem(id: 's2', glyph: '🍋', label: 'lemon'),
      StickerItem(id: 's3', glyph: '🍑', label: 'peach'),
      StickerItem(id: 's4', glyph: '🥭', label: 'mango'),
      StickerItem(id: 's5', glyph: '🧃', label: 'box'),
      StickerItem(id: 's6', glyph: '🍹', label: 'drink'),
      StickerItem(id: 's7', glyph: '☀️', label: 'sun'),
      StickerItem(id: 's8', glyph: '🔥', label: 'hot'),
    ],
  ),
  StickerPack(
    id: 'kod',
    titleRu: 'Код',
    titleEn: 'Code',
    stickers: [
      StickerItem(id: 'c1', glyph: '💻', label: 'laptop'),
      StickerItem(id: 'c2', glyph: '🧠', label: 'brain'),
      StickerItem(id: 'c3', glyph: '🚀', label: 'ship'),
      StickerItem(id: 'c4', glyph: '🐛', label: 'bug'),
      StickerItem(id: 'c5', glyph: '✅', label: 'done'),
      StickerItem(id: 'c6', glyph: '⚠️', label: 'warn'),
      StickerItem(id: 'c7', glyph: '🧩', label: 'piece'),
      StickerItem(id: 'c8', glyph: '🛠️', label: 'fix'),
    ],
  ),
  StickerPack(
    id: 'team',
    titleRu: 'Команда',
    titleEn: 'Team',
    stickers: [
      StickerItem(id: 't1', glyph: '👋', label: 'hey'),
      StickerItem(id: 't2', glyph: '🤝', label: 'deal'),
      StickerItem(id: 't3', glyph: '🎯', label: 'goal'),
      StickerItem(id: 't4', glyph: '💡', label: 'idea'),
      StickerItem(id: 't5', glyph: '📌', label: 'pin'),
      StickerItem(id: 't6', glyph: '🎉', label: 'yay'),
      StickerItem(id: 't7', glyph: '🙌', label: 'win'),
      StickerItem(id: 't8', glyph: '☕', label: 'coffee'),
    ],
  ),
];

const kEmojiPalette = <String>[
  '😀', '😃', '😄', '😁', '😆', '🥹', '😂', '🤣', '😊', '😇',
  '🙂', '😉', '😍', '🥰', '😘', '😜', '🤩', '🤔', '🤨', '😐',
  '😴', '😭', '😤', '🤯', '🥶', '🥵', '😱', '🤗', '🤫', '🫡',
  '👍', '👎', '👏', '🙏', '💪', '👀', '❤️', '🧡', '💛', '💚',
  '💙', '💜', '🖤', '🤍', '✨', '🔥', '⭐', '⚡', '🌈', '☀️',
  '🌙', '🐱', '🐶', '🦊', '🐼', '🐸', '🦄', '🍕', '🍔', '☕',
  '🍺', '🍾', '🎵', '🎮', '📱', '💻', '🚀', '🎉', '✅', '❌',
];
