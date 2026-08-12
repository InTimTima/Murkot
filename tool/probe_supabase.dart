import 'dart:convert';
import 'dart:io';

import 'package:murkot/config/supabase_config.dart';

Future<void> main() async {
  final base = SupabaseConfig.url;
  final key = SupabaseConfig.anonKey;
  final headers = {
    'apikey': key,
    'Authorization': 'Bearer $key',
  };

  Future<void> check(String name, String path) async {
    final uri = Uri.parse('$base$path');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      headers.forEach(req.headers.set);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final short =
          body.length > 180 ? '${body.substring(0, 180)}...' : body;
      stdout.writeln('[$name] HTTP ${res.statusCode}: $short');
    } catch (e) {
      stdout.writeln('[$name] ERROR: $e');
    } finally {
      client.close(force: true);
    }
  }

  await check('auth/settings', '/auth/v1/settings');
  await check('profiles', '/rest/v1/profiles?select=id&limit=1');
  await check('conversations', '/rest/v1/conversations?select=id&limit=1');
  await check('messages', '/rest/v1/messages?select=id&limit=1');
  await check('blocked_users', '/rest/v1/blocked_users?select=blocker_id&limit=1');
}
