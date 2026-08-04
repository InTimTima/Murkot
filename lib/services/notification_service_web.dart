// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';

import '../config/push_config.dart';

@JS('murkotRegisterWebPush')
external JSPromise<JSAny?> _murkotRegisterWebPush(JSString vapidPublicKey);

Future<bool> hasNotificationPermissionImpl() async {
  if (!html.Notification.supported) return false;
  return html.Notification.permission == 'granted';
}

Future<bool> requestNotificationPermissionImpl() async {
  if (!html.Notification.supported) return false;
  final permission = html.Notification.permission;
  if (permission == 'granted') return true;
  if (permission == 'denied') return false;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

Future<void> showNotificationImpl({
  required String title,
  required String body,
  String? tag,
}) async {
  if (!html.Notification.supported) return;
  if (html.Notification.permission != 'granted') return;

  html.Notification(
    title,
    body: body,
    tag: tag,
  );
}

Future<String?> registerWebPushSubscriptionImpl() async {
  if (!html.Notification.supported) return null;
  if (html.Notification.permission != 'granted') return null;

  try {
    final result = await _murkotRegisterWebPush(PushConfig.vapidPublicKey.toJS).toDart;
    if (result == null) return null;
    final value = result.dartify();
    if (value is String && value.isNotEmpty) return value;
    return null;
  } catch (e) {
    // ignore: avoid_print
    print('Web Push register failed: $e');
    return null;
  }
}
