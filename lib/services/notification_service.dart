import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart' as impl;
import 'settings_service.dart';

class NotificationService {
  NotificationService({SettingsService? settings}) : _settings = settings;

  SettingsService? _settings;
  bool _permissionGranted = false;

  bool get isEnabled =>
      (_settings?.notificationsEnabled ?? true) && _permissionGranted;

  void attachSettings(SettingsService settings) {
    _settings = settings;
  }

  Future<bool> initialize() async {
    // Do not prompt on startup — a permission dialog can hang the whole app
    // for minutes if the user ignores it. Only wire up an already-granted grant.
    _permissionGranted = await impl.hasNotificationPermissionImpl();
    if (_permissionGranted && (_settings?.notificationsEnabled ?? true)) {
      unawaited(_registerPushToken());
    }
    return isEnabled;
  }

  Future<bool> enableAndRequestPermission() async {
    await _settings?.setNotificationsEnabled(true);
    _permissionGranted = await impl.requestNotificationPermissionImpl();
    if (_permissionGranted) {
      await _registerPushToken();
    }
    return _permissionGranted;
  }

  Future<void> setUserEnabled(bool enabled) async {
    await _settings?.setNotificationsEnabled(enabled);
    if (enabled) {
      _permissionGranted = await impl.requestNotificationPermissionImpl();
      if (_permissionGranted) await _registerPushToken();
    }
  }

  Future<void> showIncomingMessage({
    required String title,
    required String body,
    required String conversationId,
  }) async {
    if (!(_settings?.notificationsEnabled ?? true)) return;

    if (!_permissionGranted) {
      _permissionGranted = await impl.requestNotificationPermissionImpl();
      if (!_permissionGranted) return;
      await _registerPushToken();
    }

    await impl.showNotificationImpl(
      title: title,
      body: body,
      tag: conversationId,
    );
  }

  Future<void> _registerPushToken() async {
    try {
      final token = await impl.registerWebPushSubscriptionImpl();
      if (token == null || token.isEmpty) return;
      if (Supabase.instance.client.auth.currentUser == null) return;

      await Supabase.instance.client.rpc(
        'upsert_device_token',
        params: {
          'p_token': token,
          'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('upsert_device_token failed: $e');
    }
  }
}
