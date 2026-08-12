import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class AppStrings {
  AppStrings(this.appLanguage, this.settingsService);

  final AppLanguage appLanguage;
  final SettingsService settingsService;

  bool get isRu => appLanguage == AppLanguage.ru;

  String _l(String key, String ru, String en) =>
      settingsService.label(key, isRu ? ru : en);

  String get appTitle => 'Murkot';
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
  String get findUsers => isRu ? 'Найти пользователя' : 'Find user';
  String get searchUsersHint =>
      isRu ? 'Введите логин' : 'Enter login';
  String get searchUsersEmptyHint => isRu
      ? 'Начните вводить логин, чтобы найти людей'
      : 'Start typing a login to find people';
  String get usersNotFound =>
      isRu ? 'Пользователи не найдены' : 'No users found';
  String get findGroup => isRu ? 'Найти группу' : 'Find group';
  String get findChannel => isRu ? 'Найти канал' : 'Find channel';
  String get joinAction => isRu ? 'Вступить' : 'Join';
  String get alreadyMember => isRu ? 'Вы участник' : 'Member';
  String get nothingFound => isRu ? 'Ничего не найдено' : 'Nothing found';
  String get foundMessages => isRu ? 'Сообщения' : 'Messages';
  String get changeAvatar => isRu ? 'Сменить аватар' : 'Change avatar';
  String get attachmentsPanel => isRu ? 'Вложения' : 'Attachments';
  String get chooseEmoji => isRu ? 'Выбрать эмодзи' : 'Choose emoji';
  String get captionHint =>
      isRu ? 'Подпись к вложениям…' : 'Caption for attachments…';
  String membersCount(int count) =>
      isRu ? 'Участников: $count' : 'Members: $count';
  String get chatWithBot =>
      isRu ? 'Написать Murkot' : 'Message Murkot';
  String get botSubtitle => isRu
      ? 'Бот отвечает в реальном времени'
      : 'Bot replies in real time';
  String get noStatus => isRu ? 'Без статуса' : 'No status';
  String get createChat => _l(PersonalizationKeys.createChat, 'Создать новый чат', 'Create new chat');
  String get createGroup => _l(PersonalizationKeys.createGroup, 'Создать новую группу', 'Create new group');
  String get createChannel => _l(PersonalizationKeys.createChannel, 'Создать новый канал', 'Create new channel');
  String get newChatTitle => isRu ? 'Новый чат' : 'New chat';
  String get newGroupTitle => isRu ? 'Новая группа' : 'New group';
  String get newChannelTitle => isRu ? 'Новый канал' : 'New channel';
  String get newChatHint => isRu ? 'Логин пользователя' : 'User login';
  String get newGroupHint => isRu ? 'Название группы' : 'Group name';
  String get newChannelHint => isRu ? 'Название канала' : 'Channel name';
  String get nameRequired => isRu ? 'Введите название' : 'Enter a name';
  String get emptyList => isRu ? 'Список пуст' : 'List is empty';
  String get openChatFailed =>
      isRu ? 'Не удалось открыть чат' : 'Could not open chat';
  String get mediaUploadFailed =>
      isRu ? 'Не удалось отправить файл' : 'Could not send file';
  String get mediaUploading =>
      isRu ? 'Отправка файла...' : 'Uploading file...';
  String get memberAdded =>
      isRu ? 'Участник добавлен' : 'Member added';
  String get memberRemoved =>
      isRu ? 'Участник удалён' : 'Member removed';
  String get memberActionFailed =>
      isRu ? 'Не удалось изменить участников' : 'Could not update members';
  String get openFile => isRu ? 'Открыть файл' : 'Open file';
  String get pickCancelled => isRu ? 'Отменено' : 'Cancelled';
  String get reply => isRu ? 'Ответить' : 'Reply';
  String get replyTo => isRu ? 'Ответ для' : 'Reply to';
  String get userBlockedBanner => isRu
      ? 'Пользователь в чёрном списке. Сообщения недоступны.'
      : 'User is blocked. Messaging is disabled.';
  String get blockedUserHidden => isRu
      ? 'Заблокированные чаты скрыты'
      : 'Blocked chats are hidden';
  String get forward => isRu ? 'Переслать' : 'Forward';
  String get forwardTo => isRu ? 'Переслать в...' : 'Forward to...';
  String get messageForwarded =>
      isRu ? 'Сообщение переслано' : 'Message forwarded';
  String get searchInChat =>
      isRu ? 'Поиск в чате' : 'Search in chat';
  String get searchInChatHint =>
      isRu ? 'Текст сообщения' : 'Message text';
  String get noSearchResults =>
      isRu ? 'Ничего не найдено' : 'No results';
  String get loadOlderMessages =>
      isRu ? 'Загрузить раньше' : 'Load earlier';
  String get enableNotificationsHint => isRu
      ? 'Разрешите уведомления в браузере, чтобы не пропускать сообщения'
      : 'Allow browser notifications to catch new messages';
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
  String get profileActions => isRu ? 'Действия' : 'Actions';
  String get editDescription =>
      isRu ? 'Изменить описание' : 'Edit description';
  String get descriptionHint =>
      isRu ? 'Коротко о группе или канале' : 'Short group or channel bio';
  String get descriptionUpdated =>
      isRu ? 'Описание обновлено' : 'Description updated';
  String get noDescription =>
      isRu ? 'Описание не указано' : 'No description yet';
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
  String get aboutUs => isRu ? 'О нас' : 'About us';
  String get aboutTitle => isRu ? 'О Murkot' : 'About Murkot';
  String get back => isRu ? 'Назад' : 'Back';
  String get notifications => isRu ? 'Уведомления' : 'Notifications';
  String get notificationsMessages =>
      isRu ? 'Уведомления о сообщениях' : 'Message notifications';
  String get notificationsHint => isRu
      ? 'Показывать системные уведомления о новых сообщениях'
      : 'Show system notifications for new messages';
  String get interfaceSection => isRu ? 'Интерфейс' : 'Interface';
  String get interfaceSectionHint => isRu
      ? 'Анимации и подсказки'
      : 'Animations and tooltips';
  String get floatingTooltips =>
      isRu ? 'Плавающие подсказки' : 'Floating tooltips';
  String get floatingTooltipsHint => isRu
      ? 'Подсказки следуют за курсором'
      : 'Tooltips follow the cursor';
  String get authSpotlight =>
      isRu ? 'Эффект на экране входа' : 'Auth screen spotlight';
  String get authSpotlightHint => isRu
      ? 'Волнистая область при уходе с карточки входа'
      : 'Wavy area when leaving the login card';
  String get smoothTheme =>
      isRu ? 'Плавная смена темы' : 'Smooth theme transition';
  String get showPassword => isRu ? 'Показать пароль' : 'Show password';
  String get hidePassword => isRu ? 'Скрыть пароль' : 'Hide password';
  String get createAccount => isRu ? 'Создайте аккаунт' : 'Create an account';
  String get signInAccount => isRu ? 'Войдите в аккаунт' : 'Sign in';
  String get register => isRu ? 'Зарегистрироваться' : 'Sign up';
  String get signIn => isRu ? 'Войти' : 'Sign in';
  String get haveAccount =>
      isRu ? 'Уже есть аккаунт? Войти' : 'Already have an account? Sign in';
  String get noAccount =>
      isRu ? 'Нет аккаунта? Создать' : 'No account? Create one';
  String get enterLogin => isRu ? 'Введите логин' : 'Enter login';
  String get enterEmail =>
      isRu ? 'Введите корректную почту' : 'Enter a valid email';
  String get minPassword =>
      isRu ? 'Минимум 6 символов' : 'At least 6 characters';
  String get circleVideo => isRu ? 'Кружок' : 'Circle';
  String get voiceNote => isRu ? 'Голосовое' : 'Voice';
  String get send => isRu ? 'Отправить' : 'Send';
  String get recording => isRu ? 'Запись…' : 'Recording…';
  String get retry => isRu ? 'Повторить' : 'Retry';
  String get loadFailed =>
      isRu ? 'Не удалось загрузить данные' : 'Failed to load data';
  String get loadingMurkot =>
      isRu ? 'Загрузка Murkot…' : 'Loading Murkot…';
  String mediaOf(int index, int total) =>
      isRu ? '$index из $total' : '$index of $total';
  String get serverTimeout => isRu
      ? 'Сервер не отвечает. Проверьте интернет-соединение и попробуйте ещё раз.'
      : 'Server is not responding. Check your internet connection and try again.';
  String get smoothThemeHint => isRu
      ? 'Шторка сверху закрывает экран, тема меняется под ней'
      : 'A curtain drops, theme switches underneath, then rises';
  String get messageDeleted =>
      isRu ? 'Сообщение удалено' : 'Message deleted';
  String get editedShort => isRu ? 'изм.' : 'edited';
  String pinnedMessageOf(int index, int total) => isRu
      ? 'Закреплённое сообщение $index из $total'
      : 'Pinned message $index of $total';
  String get micDenied =>
      isRu ? 'Нет доступа к микрофону' : 'Microphone access denied';
  String get voiceRecordFailed =>
      isRu ? 'Не удалось записать голосовое' : 'Could not record voice note';
  String videoTooLargeMb(String mb) => isRu
      ? 'Видео слишком большое ($mb МБ, максимум 50 МБ)'
      : 'Video is too large ($mb MB, max 50 MB)';
  String videoTooLarge(int mb) => videoTooLargeMb('$mb');
  String userNotFound(String login) =>
      isRu ? 'Пользователь @$login не найден' : 'User @$login not found';
  String openProfileFailed(Object e) =>
      isRu ? 'Не удалось открыть профиль: $e' : 'Could not open profile: $e';
  String blockFailed(Object e) =>
      isRu ? 'Не удалось заблокировать: $e' : 'Could not block: $e';
  String unblockFailed(Object e) =>
      isRu ? 'Не удалось разблокировать: $e' : 'Could not unblock: $e';
  String get alwaysOnline =>
      isRu ? 'Всегда на связи' : 'Always online';
  String get emailVerificationTitle =>
      isRu ? 'Подтверждение почты' : 'Email verification';
  String get emailVerificationSent => isRu
      ? 'Мы отправили код подтверждения на вашу почту.'
      : 'We sent a verification code to your email.';
  String emailVerificationSentTo(String email) => isRu
      ? 'Мы отправили код на $email. Введите его ниже или перейдите по ссылке из письма.'
      : 'We sent a code to $email. Enter it below or open the link from the email.';
  String get enterEmailCode =>
      isRu ? 'Введите код из письма' : 'Enter the code from the email';
  String get emailResent =>
      isRu ? 'Письмо отправлено повторно' : 'Email resent';
  String get confirmAction => isRu ? 'Подтвердить' : 'Confirm';
  String get resendCode =>
      isRu ? 'Отправить код ещё раз' : 'Resend code';
  String get aboutTagline => isRu
      ? 'Мессенджер со вкусом свежего сока'
      : 'A messenger with a fresh juice taste';
  String get aboutBody1 => isRu
      ? 'Murkot — это мессенджер, который мы делаем как свой продукт: '
          'чаты, группы, каналы, медиаальбомы, голосовые, кружки, '
          'стикеры и всё остальное, что нужно для живого общения. '
          'Визуальный язык — тёплый апельсиновый, с котом-маскотом, '
          'который тянется, сидит и выглядывает из каждого свободного '
          'угла интерфейса.'
      : 'Murkot is a messenger we build as our own product: chats, groups, '
          'channels, media albums, voice notes, circles, stickers, and '
          'everything else for lively conversations. The visual language is '
          'warm orange, with a cat mascot that stretches, sits, and peeks '
          'from every free corner of the UI.';
  String get aboutBody2 => isRu
      ? 'Под капотом — Flutter-клиент и Supabase: авторизация, профили, '
          'realtime-сообщения, вложения, присутствие «в сети». Проект '
          'вырос из простой идеи: сделать мессенджер «под себя», а не '
          'очередной клон чужого интерфейса. Отсюда и название, и кот, '
          'и сок — всё, что хотелось видеть на экране каждый день.'
      : 'Under the hood — a Flutter client and Supabase: auth, profiles, '
          'realtime messages, attachments, and online presence. The project '
          'grew from a simple idea: make a messenger for ourselves, not just '
          'another clone. Hence the name, the cat, and the juice — everything '
          'we wanted to see on screen every day.';
  String get aboutBody3 => isRu
      ? 'Мы собираем desktop-раскладку в три колонки, мобильную навигацию '
          'с брендовым слотом «О приложении», системные сообщения, '
          'закрепления, реакции и медиа-просмотрщик. Где-то уже гладко, '
          'где-то кот ещё дотягивается лапой — так и живём в активной '
          'разработке.'
      : 'We are building a three-column desktop layout, mobile navigation '
          'with a branded About slot, system messages, pins, reactions, and a '
          'media viewer. Some parts are already smooth; elsewhere the cat is '
          'still reaching with a paw — that is active development.';
  String get aboutTeam => isRu ? 'Команда' : 'Team';
  String get aboutPhotoSoon =>
      isRu ? 'Фото появится позже' : 'Photo coming soon';
  String get aboutCreator1Role => isRu
      ? 'Идея, продукт, дизайн и разработка клиента'
      : 'Idea, product, design, and client development';
  String get aboutCreator2Role => isRu
      ? 'Соавтор, инфраструктура и бэкенд'
      : 'Co-author, infrastructure, and backend';
  String get aboutBody4 => isRu
      ? 'Эта страница — живая заглушка раздела «О проекте». Позже здесь '
          'появятся настоящие фотографии, точные имена и более подробная '
          'история: как выбирали цвета, почему кот тянется именно так, '
          'и зачем в интерфейсе столько капель и долек цитруса.'
      : 'This page is a living stub for the About section. Later it will get '
          'real photos, exact names, and a fuller story: how we chose the '
          'colors, why the cat stretches the way it does, and why the UI has '
          'so many drops and citrus slices.';
  String get aboutBody5 => isRu
      ? 'Если ты читаешь это в ранней сборке — спасибо. Murkot ещё '
          'растёт, и каждый экран, каждая анимация и каждый кот на фоне '
          'появляются не просто так. Налей себе сока и оставайся с нами.'
      : 'If you are reading this in an early build — thank you. Murkot is '
          'still growing, and every screen, animation, and background cat '
          'is there for a reason. Pour yourself some juice and stay with us.';
}

class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppStringsScope>()
        ?.strings;
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      strings.appLanguage != oldWidget.strings.appLanguage ||
      strings.settingsService != oldWidget.strings.settingsService;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings =>
      dependOnInheritedWidgetOfExactType<AppStringsScope>()!.strings;
}
