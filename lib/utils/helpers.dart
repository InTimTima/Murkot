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

String formatLastSeen(DateTime? lastSeen, {bool isRu = true}) {
  if (lastSeen == null) {
    return isRu ? 'давно не в сети' : 'last seen a long time ago';
  }

  final local = lastSeen.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inMinutes < 1) {
    return isRu ? 'был(а) только что' : 'last seen just now';
  }
  if (diff.inMinutes < 60) {
    return isRu
        ? 'был(а) ${diff.inMinutes} мин. назад'
        : 'last seen ${diff.inMinutes} min ago';
  }
  if (diff.inHours < 24 && now.day == local.day) {
    return isRu
        ? 'был(а) в ${formatMessageTime(local)}'
        : 'last seen at ${formatMessageTime(local)}';
  }
  if (diff.inDays < 2) {
    return isRu
        ? 'был(а) вчера в ${formatMessageTime(local)}'
        : 'last seen yesterday at ${formatMessageTime(local)}';
  }
  return isRu
      ? 'был(а) ${local.day}.${local.month.toString().padLeft(2, '0')} в ${formatMessageTime(local)}'
      : 'last seen ${local.day}.${local.month.toString().padLeft(2, '0')} at ${formatMessageTime(local)}';
}
