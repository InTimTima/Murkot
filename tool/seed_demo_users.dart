import 'dart:convert';
import 'dart:io';

import 'package:murkot/config/supabase_config.dart';

/// Seeds 3 demo users with developer cards + listings for soft-launch.
///
/// Run: dart run tool/seed_demo_users.dart
Future<Map<String, dynamic>> httpJson(
  String method,
  String path, {
  Map<String, String>? headers,
  Object? body,
  String prefer = 'return=minimal',
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
    request.headers.set('Prefer', prefer);
    headers?.forEach((k, v) {
      if (k != 'Authorization' && k != 'Prefer') request.headers.set(k, v);
    });
    if (headers?['Prefer'] != null) {
      request.headers.set('Prefer', headers!['Prefer']!);
    }
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

void fail(String step, Map<String, dynamic> res) {
  stderr.writeln('FAIL [$step] HTTP ${res['status']}: ${res['raw']}');
  exit(1);
}

Future<String> ensureSession({
  required String email,
  required String password,
  required String login,
  required String emoji,
}) async {
  final signup = await httpJson(
    'POST',
    '/auth/v1/signup',
    body: {
      'email': email,
      'password': password,
      'data': {'login': login, 'avatar_emoji': emoji},
    },
  );
  final status = signup['status'] as int;
  String? accessToken;
  String? userId;

  if (status == 200 || status == 201) {
    final body = signup['body'] as Map<String, dynamic>;
    accessToken = body['access_token'] as String?;
    userId = (body['user'] as Map?)?['id'] as String? ?? body['id'] as String?;
    stdout.writeln('OK   [signup] $login');
  } else {
    stdout.writeln('INFO [signup] $login HTTP $status — trying login');
  }

  if (accessToken == null) {
    final loginRes = await httpJson(
      'POST',
      '/auth/v1/token?grant_type=password',
      body: {'email': email, 'password': password},
    );
    if ((loginRes['status'] as int) >= 400) {
      fail('login $login', loginRes);
    }
    final body = loginRes['body'] as Map<String, dynamic>;
    accessToken = body['access_token'] as String;
    userId = (body['user'] as Map?)?['id'] as String? ??
        body['id'] as String?;
    stdout.writeln('OK   [login] $login');
  }

  final auth = {'Authorization': 'Bearer $accessToken'};
  await Future<void>.delayed(const Duration(milliseconds: 500));

  // Ensure profile row exists, then patch developer card fields.
  final profileGet = await httpJson(
    'GET',
    '/rest/v1/profiles?select=id&limit=1',
    headers: auth,
  );
  if ((profileGet['status'] as int) >= 400) {
    fail('profile get $login', profileGet);
  }

  if (userId == null) {
    // Decode sub from JWT payload (middle segment).
    final parts = accessToken.split('.');
    if (parts.length >= 2) {
      final padded = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(padded))) as Map;
      userId = payload['sub'] as String?;
    }
  }
  if (userId == null) {
    stderr.writeln('FAIL [$login] no user id');
    exit(1);
  }

  // Never touch email here: column grants exclude UPDATE on email,
  // and Prefer return=representation would require SELECT on email.
  final patch = await httpJson(
    'PATCH',
    '/rest/v1/profiles?id=eq.$userId',
    headers: auth,
    prefer: 'return=minimal',
    body: {
      'login': login,
      'avatar_emoji': emoji,
      'status': 'Ищу команду в Murkot',
    },
  );
  if ((patch['status'] as int) >= 400) {
    stderr.writeln(
      'WARN profile write failed for $login — '
      'run supabase/fix_profiles_grants.sql then re-run seed.\n'
      'patch=${patch['raw']}',
    );
    fail('profile write $login', patch);
  }

  return accessToken;
}

Future<void> patchCard(
  String token, {
  required String status,
  required List<String> skills,
  required String level,
  required String city,
  String? github,
}) async {
  final res = await httpJson(
    'PATCH',
    '/rest/v1/profiles?id=eq.${await _uid(token)}',
    headers: {'Authorization': 'Bearer $token'},
    body: {
      'dev_status': status,
      'skills': skills,
      'experience_level': level,
      'city': city,
      if (github != null) 'github_url': github,
      'status': 'Готов к знакомству на доске',
    },
  );
  if ((res['status'] as int) >= 400) fail('patch card', res);
  stdout.writeln('OK   [card] $status / ${skills.join(",")}');
}

Future<String> _uid(String accessToken) async {
  final parts = accessToken.split('.');
  final padded = base64Url.normalize(parts[1]);
  final payload = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map;
  return payload['sub'] as String;
}

Future<void> createListing(
  String token, {
  required String type,
  required String title,
  required String description,
  required List<String> skills,
  required String compensation,
}) async {
  final uid = await _uid(token);
  final res = await httpJson(
    'POST',
    '/rest/v1/listings',
    headers: {'Authorization': 'Bearer $token'},
    body: {
      'author_id': uid,
      'type': type,
      'title': title,
      'description': description,
      'skills': skills,
      'compensation': compensation,
      'is_active': true,
    },
  );
  if ((res['status'] as int) >= 400) fail('listing $title', res);
  stdout.writeln('OK   [listing] $title');
}

Future<void> main() async {
  const password = 'MurkotDemo1!';
  stdout.writeln('=== Seed demo users ===');
  stdout.writeln('password for all: $password\n');

  final demo = <Map<String, dynamic>>[
    {
      'login': 'demo_anna',
      'email': 'demo.anna.murkot@gmail.com',
      'emoji': '🦊',
      'status': 'looking_for_team',
      'skills': ['Flutter', 'Dart', 'Firebase'],
      'level': 'middle',
      'city': 'Москва',
      'github': 'https://github.com/demo-anna',
      'listing': {
        'type': 'looking_for_team',
        'title': 'Flutter middle ищет стартап',
        'description':
            'Делаю мобильные приложения 3+ года. Хочу в продукт с живыми пользователями, готов(а) к equity.',
        'skills': ['Flutter', 'Dart', 'UI'],
        'compensation': 'equity',
      },
    },
    {
      'login': 'demo_boris',
      'email': 'demo.boris.murkot@gmail.com',
      'emoji': '🐻',
      'status': 'looking_for_members',
      'skills': ['Go', 'Postgres', 'Docker'],
      'level': 'senior',
      'city': 'Санкт-Петербург',
      'github': 'https://github.com/demo-boris',
      'listing': {
        'type': 'looking_for_members',
        'title': 'Ищем мобильного в B2B SaaS',
        'description':
            'Бэкенд готов, нужен Flutter/RN для MVP клиента. Частичная занятость, можно удалённо.',
        'skills': ['Flutter', 'Go', 'API'],
        'compensation': 'paid',
      },
    },
    {
      'login': 'demo_kira',
      'email': 'demo.kira.murkot@gmail.com',
      'emoji': '🐱',
      'status': 'open_to_offers',
      'skills': ['React', 'TypeScript', 'Figma'],
      'level': 'junior',
      'city': 'Казань',
      'github': null,
      'listing': {
        'type': 'looking_for_team',
        'title': 'Frontend junior — pet / стартап',
        'description':
            'Верстаю и пишу на React/TS. Хочу прокачаться в команде, могу помочь с UI.',
        'skills': ['React', 'TypeScript', 'CSS'],
        'compensation': 'pet_project',
      },
    },
  ];

  for (final u in demo) {
    final token = await ensureSession(
      email: u['email'] as String,
      password: password,
      login: u['login'] as String,
      emoji: u['emoji'] as String,
    );
    await patchCard(
      token,
      status: u['status'] as String,
      skills: (u['skills'] as List).cast<String>(),
      level: u['level'] as String,
      city: u['city'] as String,
      github: u['github'] as String?,
    );
    final listing = u['listing'] as Map<String, dynamic>;
    await createListing(
      token,
      type: listing['type'] as String,
      title: listing['title'] as String,
      description: listing['description'] as String,
      skills: (listing['skills'] as List).cast<String>(),
      compensation: listing['compensation'] as String,
    );
    stdout.writeln('');
  }

  stdout.writeln('DONE. Logins:');
  for (final u in demo) {
    stdout.writeln(
      '  ${u['login']} / ${u['email']} / $password',
    );
  }
}
