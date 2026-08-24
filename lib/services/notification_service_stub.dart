import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

Future<void> _ensureReady() async {
  if (_ready) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
  _ready = true;
}

Future<bool> hasNotificationPermissionImpl() async {
  if (kIsWeb) return false;
  await _ensureReady();
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  return await android?.areNotificationsEnabled() ?? false;
}

Future<bool> requestNotificationPermissionImpl() async {
  if (kIsWeb) return false;
  await _ensureReady();
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  final granted = await android?.requestNotificationsPermission();
  return granted ?? true;
}

Future<void> showNotificationImpl({
  required String title,
  required String body,
  String? tag,
}) async {
  await _ensureReady();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'murkot_messages',
      'Murkot',
      channelDescription: 'Incoming Murkot messages',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  await _plugin.show(tag?.hashCode ?? 0, title, body, details);
}

Future<String?> registerWebPushSubscriptionImpl() async => null;
