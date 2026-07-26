const kMessageCharLimit = 4096;

const kRandomAvatarEmojis = [
  '😀', '🦊', '🐱', '🐶', '🌟', '🎮', '🎨', '🔥',
  '💎', '🚀', '🌈', '🎭', '🎵', '⚡', '🍀', '🦄',
];

String pickRandomEmoji([int? seed]) {
  if (seed != null) {
    return kRandomAvatarEmojis[seed.abs() % kRandomAvatarEmojis.length];
  }
  return kRandomAvatarEmojis[
      DateTime.now().millisecondsSinceEpoch % kRandomAvatarEmojis.length];
}

int calculateAge(DateTime birthday) {
  final now = DateTime.now();
  var age = now.year - birthday.year;
  if (now.month < birthday.month ||
      (now.month == birthday.month && now.day < birthday.day)) {
    age--;
  }
  return age;
}

String formatBirthday(DateTime birthday) {
  final months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  return '${birthday.day} ${months[birthday.month - 1]} ${birthday.year}';
}

String formatMessageTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String formatDateSeparator(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDate = DateTime(date.year, date.month, date.day);

  if (messageDate == today) return 'Сегодня';
  if (messageDate == today.subtract(const Duration(days: 1))) return 'Вчера';

  final months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

List<String> splitMessageText(String text, {int limit = kMessageCharLimit}) {
  if (text.length <= limit) return [text];
  final parts = <String>[];
  var remaining = text;
  while (remaining.isNotEmpty) {
    if (remaining.length <= limit) {
      parts.add(remaining);
      break;
    }
    parts.add(remaining.substring(0, limit));
    remaining = remaining.substring(limit);
  }
  return parts;
}

bool matchesSearch(String haystack, String query) {
  return haystack.toLowerCase().contains(query.toLowerCase());
}
