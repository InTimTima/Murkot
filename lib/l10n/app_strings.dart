import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class AppStrings {
  AppStrings(this.appLanguage, this.settingsService);

  final AppLanguage appLanguage;
  final SettingsService settingsService;

  bool get isRu => appLanguage == AppLanguage.ru;

  String _l(String key, String ru, String en) =>
      settingsService.label(key, isRu ? ru : en);

  String get appTitle => 'Tujh Messenger';
  String get profile => _l(PersonalizationKeys.profile, 'Профиль', 'Profile');
  String get chats => _l(PersonalizationKeys.chats, 'Чаты', 'Chats');
  String get groups => _l(PersonalizationKeys.groups, 'Группы', 'Groups');
  String get channels => _l(PersonalizationKeys.channels, 'Каналы', 'Channels');
  String get settingsTitle => _l(PersonalizationKeys.settings, 'Настройки', 'Settings');
  String get status => isRu ? 'Статус' : 'Status';
  String get email => isRu ? 'Почта' : 'Email';
  String get login => isRu ? 'Логин' : 'Login';
  String get logout => isRu ? 'Выйти из аккаунта' : 'Log out';
  String get logoutTitle => isRu ? 'Выйти из аккаунта?' : 'Log out?';
  String get logoutMessage =>
      isRu ? 'Вы будете перенаправлены на экран входа.' : 'You will be redirected to the login screen.';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get yes => isRu ? 'Да' : 'Yes';
  String get save => isRu ? 'Сохранить' : 'Save';
  String get confirmLogout => isRu ? 'Выйти' : 'Log out';
  String get changeAvatarHint =>
      isRu ? 'Нажмите на аватар, чтобы изменить' : 'Tap avatar to change';
  String get statusHint => isRu ? 'Чем заняты?' : 'What are you up to?';
  String get gallery => isRu ? 'Галерея' : 'Gallery';
  String get camera => isRu ? 'Камера' : 'Camera';
  String get removeAvatar => isRu ? 'Удалить аватар' : 'Remove avatar';
  String get avatarUpdated => isRu ? 'Аватар обновлён' : 'Avatar updated';
  String get avatarRemoved => isRu ? 'Аватар удалён' : 'Avatar removed';
  String get statusSaved => isRu ? 'Статус сохранён' : 'Status saved';
  String get languageLabel => isRu ? 'Язык' : 'Language';
  String get textSize => isRu ? 'Размер текста' : 'Text size';
  String get theme => isRu ? 'Тема' : 'Theme';
  String get themeSystem => isRu ? 'Системная' : 'System';
  String get themeLight => isRu ? 'Светлая' : 'Light';
  String get themeDark => isRu ? 'Тёмная' : 'Dark';
  String get textSmall => isRu ? 'Мелкий' : 'Small';
  String get textNormal => isRu ? 'Обычный' : 'Normal';
  String get textLarge => isRu ? 'Крупный' : 'Large';
  String get languageRu => 'Русский';
  String get languageEn => 'English';
  String get search => isRu ? 'Поиск' : 'Search';
  String get searchChats => isRu ? 'Поиск по чатам' : 'Search chats';
  String get searchGroups => isRu ? 'Поиск по группам' : 'Search groups';
  String get searchChannels => isRu ? 'Поиск по каналам' : 'Search channels';
  String get createChat => _l(PersonalizationKeys.createChat, 'Создать новый чат', 'Create new chat');
  String get createGroup => _l(PersonalizationKeys.createGroup, 'Создать новую группу', 'Create new group');
  String get createChannel => _l(PersonalizationKeys.createChannel, 'Создать новый канал', 'Create new channel');
  String get newChatTitle => isRu ? 'Новый чат' : 'New chat';
  String get newGroupTitle => isRu ? 'Новая группа' : 'New group';
  String get newChannelTitle => isRu ? 'Новый канал' : 'New channel';
  String get newChatHint => isRu ? 'Имя собеседника' : 'Contact name';
  String get newGroupHint => isRu ? 'Название группы' : 'Group name';
  String get newChannelHint => isRu ? 'Название канала' : 'Channel name';
  String get nameRequired => isRu ? 'Введите название' : 'Enter a name';
  String get emptyList => isRu ? 'Список пуст' : 'List is empty';
  String get online => _l(PersonalizationKeys.online, 'в сети', 'online');
  String get offline => _l(PersonalizationKeys.offline, 'не в сети', 'offline');
  String get typing => _l(PersonalizationKeys.typing, 'печатает', 'typing');
  String typingUsers(String names) => isRu ? '$names печатает...' : '$names is typing...';
  String onlineCount(int n) => isRu ? '$n в сети' : '$n online';
  String subscriberCount(int n) => isRu ? '$n подписчиков' : '$n subscribers';
  String get noMessages => isRu ? 'Нет сообщений' : 'No messages';
  String get messageHint => _l(PersonalizationKeys.message, 'Сообщение...', 'Message...');
  String get editMessage => isRu ? 'Редактировать' : 'Edit';
  String get deleteForMe => isRu ? 'Удалить для себя' : 'Delete for me';
  String get deleteForAll => isRu ? 'Удалить для всех' : 'Delete for everyone';
  String get deleteForAllConfirm =>
      isRu ? 'Сообщение будет удалено у всех участников.' : 'Message will be deleted for everyone.';
  String get addReaction => isRu ? 'Добавить реакцию' : 'Add reaction';
  String get pinForMe => isRu ? 'Закрепить для себя' : 'Pin for me';
  String get pinForAll => isRu ? 'Закрепить для всех' : 'Pin for everyone';
  String get voice => isRu ? 'Голос' : 'Voice';
  String get video => isRu ? 'Видео' : 'Video';
  String get image => isRu ? 'Фото' : 'Photo';
  String get music => isRu ? 'Музыка' : 'Music';
  String get sticker => isRu ? 'Стикер' : 'Sticker';
  String get gif => isRu ? 'GIF' : 'GIF';
  String get file => isRu ? 'Файл' : 'File';
  String get profileInfo => _l(PersonalizationKeys.info, 'Информация', 'Info');
  String get images => isRu ? 'Фото' : 'Photos';
  String get videos => isRu ? 'Видео' : 'Videos';
  String get voices => isRu ? 'Голосовые' : 'Voice';
  String get files => isRu ? 'Файлы' : 'Files';
  String get noMedia => isRu ? 'Нет медиа' : 'No media';
  String get blockUser => isRu ? 'Заблокировать' : 'Block';
  String get unblockUser => isRu ? 'Разблокировать' : 'Unblock';
  String blockUserConfirm(String name) =>
      isRu ? 'Заблокировать $name?' : 'Block $name?';
  String unblockUserConfirm(String name) =>
      isRu ? 'Разблокировать $name?' : 'Unblock $name?';
  String get deleteChat => isRu ? 'Удалить чат' : 'Delete chat';
  String get deleteChatConfirm => isRu ? 'Чат будет удалён.' : 'Chat will be deleted.';
  String get leaveGroup => isRu ? 'Выйти из группы' : 'Leave group';
  String get leaveChannel => isRu ? 'Отписаться от канала' : 'Leave channel';
  String get leaveGroupConfirm =>
      isRu ? 'Вы покинете группу.' : 'You will leave the group.';
  String get leaveChannelConfirm =>
      isRu ? 'Вы отпишетесь от канала.' : 'You will leave the channel.';
  String get deleteGroupOrChannel => isRu ? 'Удалить' : 'Delete';
  String deleteGroupOrChannelConfirm(String name) =>
      isRu ? 'Удалить «$name» навсегда?' : 'Delete "$name" permanently?';
  String get rename => isRu ? 'Переименовать' : 'Rename';
  String get manageMembers => isRu ? 'Управление участниками' : 'Manage members';
  String get members => isRu ? 'Участники' : 'Members';
  String get addMember => isRu ? 'Добавить участника' : 'Add member';
  String get changeName => isRu ? 'Сменить имя' : 'Change name';
  String get changeNameHint => isRu ? 'Новое имя' : 'New name';
  String get nameChanged => isRu ? 'Имя изменено' : 'Name changed';
  String get chooseWallpaper => isRu ? 'Выбрать обои' : 'Choose wallpaper';
  String get uploadWallpaper => isRu ? 'Загрузить своё фото' : 'Upload custom photo';
  String get deleteAccount => isRu ? 'Удалить аккаунт' : 'Delete account';
  String get deleteAccountTitle => isRu ? 'Удалить аккаунт?' : 'Delete account?';
  String get deleteAccountMessage =>
      isRu ? 'Это необратимо. Введите «удалить аккаунт» для подтверждения.' : 'Irreversible. Type phrase to confirm.';
  String get deleteAccountHint => isRu ? 'удалить аккаунт' : 'delete account';
  String get deleteAccountPhrase => isRu ? 'удалить аккаунт' : 'delete account';
  String get deleteAccountValidation =>
      isRu ? 'Введите «удалить аккаунт»' : 'Type the confirmation phrase';
  String get deleteAccountConfirm => isRu ? 'Удалить' : 'Delete';
  String get blacklist => isRu ? 'Чёрный список' : 'Blacklist';
  String blacklistCount(int n) => isRu ? '$n заблокированных' : '$n blocked';
  String get blacklistEmpty => isRu ? 'Чёрный список пуст' : 'Blacklist is empty';
  String get changeEmail => isRu ? 'Сменить почту' : 'Change email';
  String get changeEmailHint => isRu ? 'Новая почта' : 'New email';
  String get passwordHint => isRu ? 'Пароль' : 'Password';
  String get passwordRequired => isRu ? 'Введите пароль' : 'Enter password';
  String get emailChanged => isRu ? 'Почта изменена' : 'Email changed';
  String get birthday => isRu ? 'Дата рождения' : 'Birthday';
  String get setBirthday => isRu ? 'Указать дату рождения' : 'Set birthday';
  String get notSet => isRu ? 'Не указана' : 'Not set';
  String ageYears(int n) => isRu ? '$n лет' : '$n years old';
  String get channelReadOnly =>
      isRu ? 'Писать в канал могут только админы' : 'Only admins can post in channels';
  String get comments => isRu ? 'Комментарии' : 'Comments';
  String get commentHint => isRu ? 'Комментарий...' : 'Comment...';
  String get showMore => isRu ? 'Показать ещё' : 'Show more';
  String get personalization => isRu ? 'Персонализация' : 'Personalization';
  String get personalizationHint =>
      isRu ? 'Замените стандартные подписи на свои' : 'Replace default labels with your own';
  String get resetLabels => isRu ? 'Сбросить' : 'Reset';
}

class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      strings.appLanguage != oldWidget.strings.appLanguage ||
      strings.settingsService != oldWidget.strings.settingsService;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings =>
      dependOnInheritedWidgetOfExactType<AppStringsScope>()!.strings;
}
