import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart' as impl;

class NotificationService {
  bool _enabled = false;
  bool get isEnabled => _enabled;

  Future<bool> initialize() async {
    // Do not prompt on startup — a permission dialog can hang the whole app
    // for minutes if the user ignores it. Only wire up an already-granted grant.
    _enabled = await impl.hasNotificationPermissionImpl();
    if (_enabled) {
      unawaited(_registerPushToken());
    }
    return _enabled;
  }

  Future<void> showIncomingMessage({
    required String title,
    required String body,
    required String conversationId,
  }) async {
    if (!_enabled) {
      _enabled = await impl.requestNotificationPermissionImpl();
      if (!_enabled) return;
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
