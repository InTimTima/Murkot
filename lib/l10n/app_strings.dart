import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class AppStrings {
  AppStrings(this.appLanguage);

  final AppLanguage appLanguage;

  bool get isRu => appLanguage == AppLanguage.ru;

  String get appTitle => isRu ? 'Tujh Messenger' : 'Tujh Messenger';
  String get profile => isRu ? 'Профиль' : 'Profile';
  String get chats => isRu ? 'Чаты' : 'Chats';
  String get settings => isRu ? 'Настройки' : 'Settings';
  String get status => isRu ? 'Статус' : 'Status';
  String get email => isRu ? 'Почта' : 'Email';
  String get login => isRu ? 'Логин' : 'Login';
  String get logout => isRu ? 'Выйти из аккаунта' : 'Log out';
  String get logoutTitle => isRu ? 'Выйти из аккаунта?' : 'Log out?';
  String get logoutMessage =>
      isRu ? 'Вы будете перенаправлены на экран входа.' : 'You will be redirected to the login screen.';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
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
  String get chatsPlaceholder =>
      isRu ? 'Список чатов скоро появится' : 'Chat list coming soon';
  String get emailNotVerified =>
      isRu ? 'Подтверждение почты будет добавлено позже' : 'Email verification coming soon';
}

extension AppStringsContext on BuildContext {
  AppStrings get strings {
    final settings = dependOnInheritedWidgetOfExactType<AppStringsScope>();
    return settings?.strings ?? AppStrings(AppLanguage.ru);
  }
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
      strings.appLanguage != oldWidget.strings.appLanguage;
}
