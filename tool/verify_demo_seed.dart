import 'dart:convert';
import 'dart:io';

import 'package:murkot/config/supabase_config.dart';

Future<Map<String, dynamic>> httpJson(
  String method,
  String path, {
  String? token,
  Object? body,
}) async {
  final client = HttpClient();
  try {
    final request =
        await client.openUrl(method, Uri.parse('${SupabaseConfig.url}$path'));
    request.headers.set('apikey', SupabaseConfig.anonKey);
    request.headers.set(
      'Authorization',
      'Bearer ${token ?? SupabaseConfig.anonKey}',
    );
    request.headers.set('Content-Type', 'application/json');
    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return {
      'status': response.statusCode,
      'body': text.isEmpty ? null : jsonDecode(text),
    };
  } finally {
    client.close(force: true);
  }
}

Future<void> main() async {
  final login = await httpJson(
    'POST',
    '/auth/v1/token?grant_type=password',
    body: {
      'email': 'demo.anna.murkot@gmail.com',
      'password': 'MurkotDemo1!',
    },
  );
  if ((login['status'] as int) >= 400) {
    stderr.writeln('login failed: ${login['body']}');
    exit(1);
  }
  final token = (login['body'] as Map)['access_token'] as String;

  final listings = await httpJson(
    'GET',
    '/rest/v1/listings?select=title,type,is_active&is_active=eq.true&order=created_at.desc&limit=10',
    token: token,
  );
  final profiles = await httpJson(
    'GET',
    '/rest/v1/public_profiles?select=login,city,dev_status&login=in.(demo_anna,demo_boris,demo_kira)',
    token: token,
  );

  stdout.writeln('listings HTTP ${listings['status']}:');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(listings['body']));
  stdout.writeln('profiles HTTP ${profiles['status']}:');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(profiles['body']));

  final listingOk = listings['status'] == 200 &&
      (listings['body'] as List).any((e) => e['title'] == 'Flutter middle ищет стартап');
  final profileOk = profiles['status'] == 200 &&
      (profiles['body'] as List).length >= 3;
  if (!listingOk || !profileOk) {
    stderr.writeln('VERIFY FAIL listingOk=$listingOk profileOk=$profileOk');
    exit(1);
  }
  stdout.writeln('VERIFY OK');
}
