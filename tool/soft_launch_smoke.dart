import 'dart:convert';
import 'dart:io';

import 'package:murkot/config/supabase_config.dart';

/// Soft-launch smoke: demo login + board RPCs (listings, people, profile).
///
///   dart run tool/soft_launch_smoke.dart
Future<Map<String, dynamic>> httpJson(
  String method,
  String path, {
  Map<String, String>? headers,
  Object? body,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('${SupabaseConfig.url}$path');
    final request = await client.openUrl(method, uri);
    request.headers.set('apikey', SupabaseConfig.anonKey);
    request.headers.set(
      'Authorization',
      headers?['Authorization'] ?? 'Bearer ${SupabaseConfig.anonKey}',
    );
    request.headers.set('Content-Type', 'application/json');
    headers?.forEach((k, v) {
      if (k != 'Authorization') request.headers.set(k, v);
    });
    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    dynamic decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      decoded = text;
    }
    return {'status': response.statusCode, 'body': decoded, 'raw': text};
  } finally {
    client.close(force: true);
  }
}

void expectOk(String step, Map<String, dynamic> res, {List<int>? ok}) {
  final allowed = ok ?? const [200, 201];
  final status = res['status'] as int;
  if (!allowed.contains(status)) {
    stderr.writeln('FAIL [$step] HTTP $status: ${res['raw']}');
    exit(1);
  }
  stdout.writeln('OK   [$step] HTTP $status');
}

Future<void> main() async {
  const email = 'demo.anna.murkot@gmail.com';
  const password = 'MurkotDemo1!';

  stdout.writeln('=== Soft-launch smoke (demo_anna) ===');

  final loginRes = await httpJson(
    'POST',
    '/auth/v1/token?grant_type=password',
    body: {'email': email, 'password': password},
  );
  expectOk('demo login', loginRes);
  final token =
      (loginRes['body'] as Map<String, dynamic>)['access_token'] as String;
  final auth = {'Authorization': 'Bearer $token'};

  final profile = await httpJson(
    'POST',
    '/rest/v1/rpc/get_own_profile',
    headers: auth,
    body: <String, dynamic>{},
  );
  expectOk('get_own_profile', profile);

  final listings = await httpJson(
    'GET',
    '/rest/v1/listings?select=id,title,author:profiles!listings_author_id_fkey(id,login)&limit=5',
    headers: auth,
  );
  expectOk('listings embed', listings);
  final listingRows = listings['body'] as List<dynamic>;
  stdout.writeln('OK   [listings] count=${listingRows.length}');

  final people = await httpJson(
    'POST',
    '/rest/v1/rpc/search_people',
    headers: auth,
    body: {
      'p_query': null,
      'p_skill': null,
      'p_city': null,
      'p_dev_status': null,
      'p_limit': 10,
      'p_offset': 0,
    },
  );
  expectOk('search_people', people);
  final peopleRows = people['body'] as List<dynamic>;
  stdout.writeln('OK   [people] count=${peopleRows.length}');

  final pub = await httpJson(
    'POST',
    '/rest/v1/rpc/get_public_profile_by_login',
    headers: auth,
    body: {'p_login': 'demo_boris'},
  );
  expectOk('get_public_profile_by_login', pub);
  final pubRows = pub['body'] as List<dynamic>;
  if (pubRows.isEmpty) {
    stderr.writeln('FAIL [public profile] demo_boris not found');
    exit(1);
  }
  stdout.writeln(
    'OK   [public profile] login=${(pubRows.first as Map)['login']}',
  );

  final matchFeed = await httpJson(
    'POST',
    '/rest/v1/rpc/get_match_feed',
    headers: auth,
    body: {'p_limit': 5},
  );
  expectOk('get_match_feed', matchFeed);

  final myResponses = await httpJson(
    'GET',
    '/rest/v1/listing_responses?select=id,listing_id,status&limit=5',
    headers: auth,
  );
  expectOk('listing_responses select', myResponses);

  stdout.writeln('\nALL SOFT-LAUNCH CHECKS PASSED');
}
