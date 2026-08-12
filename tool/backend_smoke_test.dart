import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:murkot/config/supabase_config.dart';

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
    request.headers.set('Authorization',
        headers?['Authorization'] ?? 'Bearer ${SupabaseConfig.anonKey}');
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Prefer', 'return=representation');
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
    return {
      'status': response.statusCode,
      'body': decoded,
      'raw': text,
    };
  } finally {
    client.close(force: true);
  }
}

void expectOk(String step, Map<String, dynamic> res, {List<int>? ok}) {
  final allowed = ok ?? [200, 201];
  final status = res['status'] as int;
  if (!allowed.contains(status)) {
    stderr.writeln('FAIL [$step] HTTP $status: ${res['raw']}');
    exit(1);
  }
  stdout.writeln('OK   [$step] HTTP $status');
}

Future<void> main() async {
  final rnd = Random().nextInt(999999).toString().padLeft(6, '0');
  final email = 'smoke_$rnd@gmail.com';
  final password = 'TestPass_$rnd';
  final login = 'smoke_$rnd';

  stdout.writeln('=== Backend smoke test ===');
  stdout.writeln('user: $login / $email');

  // 1) Sign up
  final signup = await httpJson(
    'POST',
    '/auth/v1/signup',
    body: {
      'email': email,
      'password': password,
      'data': {'login': login, 'avatar_emoji': 'rocket'},
    },
  );
  expectOk('signup', signup);

  final signupBody = signup['body'] as Map<String, dynamic>;
  var accessToken = signupBody['access_token'] as String?;
  final userId = (signupBody['user'] as Map<String, dynamic>?)?['id'] as String? ??
      signupBody['id'] as String?;

  if (accessToken == null) {
    // Email confirmation may be required — try password login anyway.
    stdout.writeln('INFO signup returned no session (email confirm?). Trying login...');
    final loginRes = await httpJson(
      'POST',
      '/auth/v1/token?grant_type=password',
      body: {'email': email, 'password': password},
    );
    if ((loginRes['status'] as int) >= 400) {
      stderr.writeln(
        'FAIL [login after signup] HTTP ${loginRes['status']}: ${loginRes['raw']}\n'
        'Hint: disable Confirm email in Supabase Auth settings for local tests.',
      );
      exit(1);
    }
    expectOk('login', loginRes);
    accessToken = (loginRes['body'] as Map<String, dynamic>)['access_token'] as String;
  } else {
    stdout.writeln('OK   [session] obtained from signup');
  }

  final auth = {'Authorization': 'Bearer $accessToken'};

  // 2) Profile exists via security-definer RPC (select=* fails without email grant)
  await Future<void>.delayed(const Duration(milliseconds: 800));
  final profile = await httpJson(
    'POST',
    '/rest/v1/rpc/get_own_profile',
    headers: auth,
    body: {},
  );
  expectOk('get_own_profile', profile);
  final profiles = profile['body'] as List<dynamic>;
  if (profiles.isEmpty) {
    final upsert = await httpJson(
      'POST',
      '/rest/v1/profiles',
      headers: {...auth, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
      body: {
        'id': userId,
        'login': login,
        'email': email,
        'avatar_emoji': 'rocket',
        'status': 'online',
      },
    );
    expectOk('profile upsert', upsert, ok: [200, 201]);
  } else {
    stdout.writeln('OK   [profile] login=${(profiles.first as Map)['login']}');
  }

  // 3) Create conversation via RPC
  final conv = await httpJson(
    'POST',
    '/rest/v1/rpc/create_conversation',
    headers: auth,
    body: {
      'p_type': 'group',
      'p_name': 'Smoke Chat $rnd',
      'p_emoji': 'rocket',
    },
  );
  expectOk('create_conversation', conv);
  final convBody = conv['body'];
  final convId = convBody is Map
      ? convBody['id'] as String
      : (convBody as List).first['id'] as String;
  stdout.writeln('OK   [conversation] id=$convId');

  // 4) Send message
  final msg = await httpJson(
    'POST',
    '/rest/v1/messages',
    headers: auth,
    body: {
      'conversation_id': convId,
      'sender_id': userId,
      'type': 'text',
      'content': 'Hello from smoke test $rnd',
    },
  );
  expectOk('send message', msg, ok: [200, 201]);
  final msgList = msg['body'] is List ? msg['body'] as List : [msg['body']];
  final messageId = (msgList.first as Map)['id'] as String;
  stdout.writeln('OK   [message] id=$messageId');

  // 5) Read messages back
  final msgs = await httpJson(
    'GET',
    '/rest/v1/messages?conversation_id=eq.$convId&select=id,content,type',
    headers: auth,
  );
  expectOk('list messages', msgs);
  final contents = (msgs['body'] as List)
      .map((e) => (e as Map)['content'] as String)
      .toList();
  if (!contents.any((c) => c.contains(rnd))) {
    stderr.writeln('FAIL [list messages] content not found: $contents');
    exit(1);
  }
  stdout.writeln('OK   [list messages] found sent content');

  // 6) Reaction
  final reaction = await httpJson(
    'POST',
    '/rest/v1/message_reactions',
    headers: auth,
    body: {
      'message_id': messageId,
      'user_id': userId,
      'emoji': 'fire',
    },
  );
  expectOk('reaction', reaction, ok: [200, 201]);

  // 7) Blocklist
  final block = await httpJson(
    'POST',
    '/rest/v1/blocked_users',
    headers: auth,
    body: {
      'blocker_id': userId,
      'blocked_login': 'someone_else',
    },
  );
  expectOk('block user', block, ok: [200, 201]);

  // 8) Cleanup conversation
  final del = await httpJson(
    'DELETE',
    '/rest/v1/conversations?id=eq.$convId',
    headers: auth,
  );
  expectOk('delete conversation', del, ok: [200, 204]);

  stdout.writeln('\nALL CHECKS PASSED');
}
