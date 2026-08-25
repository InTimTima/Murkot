import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:murkot/config/supabase_config.dart';

Future<Map<String, dynamic>> httpJson(String method, String path, {Map<String, String>? headers, Object? body, String prefer = 'return=minimal'}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('${SupabaseConfig.url}$path');
    final req = await client.openUrl(method, uri);
    req.headers.set('apikey', SupabaseConfig.anonKey);
    req.headers.set('Authorization', headers?['Authorization'] ?? 'Bearer ${SupabaseConfig.anonKey}');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', prefer);
    headers?.forEach((k, v) { if (k != 'Authorization' && k != 'Prefer') req.headers.set(k, v); });
    if (headers?['Prefer'] != null) req.headers.set('Prefer', headers!['Prefer']!);
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    dynamic decoded;
    try { decoded = text.isEmpty ? null : jsonDecode(text); } catch (_) { decoded = text; }
    return {'status': resp.statusCode, 'body': decoded, 'raw': text};
  } finally { client.close(force: true); }
}

void fail(String step, Map<String, dynamic> res) { stderr.writeln('FAIL [$step] ${res['status']}: ${res['raw']}'); exit(1); }

Future<String> ensureSession({required String email, required String password, required String login, required String emoji}) async {
  final signup = await httpJson('POST', '/auth/v1/signup', body: {'email': email, 'password': password, 'data': {'login': login, 'avatar_emoji': emoji}});
  int status = signup['status'] as int;
  String? token; String? uid;
  if (status == 200 || status == 201) {
    final b = signup['body'] as Map<String, dynamic>;
    token = b['access_token'] as String?; uid = (b['user'] as Map?)?['id'] as String? ?? b['id'] as String?;
    stdout.writeln('signup $login');
  }
  if (token == null) {
    final loginRes = await httpJson('POST', '/auth/v1/token?grant_type=password', body: {'email': email, 'password': password});
    if ((loginRes['status'] as int) >= 400) fail('login $login', loginRes);
    final b = loginRes['body'] as Map<String, dynamic>;
    token = b['access_token'] as String; uid = (b['user'] as Map?)?['id'] as String? ?? b['id'] as String?;
    stdout.writeln('login $login');
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (uid == null) {
    final parts = token.split('.');
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
    uid = payload['sub'] as String?;
  }
  final auth = {'Authorization': 'Bearer $token'};
  final patch = await httpJson('PATCH', '/rest/v1/profiles?id=eq.$uid', headers: auth, prefer: 'return=minimal', body: {'login': login, 'avatar_emoji': emoji, 'status': 'Бот Murkot'});
  if ((patch['status'] as int) >= 400) { stderr.writeln('profile $login failed ${patch['raw']}'); }
  return token;
}

Future<void> patchCard(String token, {required String status, required List<String> skills, required String level, required String city, String? github}) async {
  final parts = token.split('.'); final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map; final uid = payload['sub'] as String;
  final res = await httpJson('PATCH', '/rest/v1/profiles?id=eq.$uid', headers: {'Authorization': 'Bearer $token'}, body: {'dev_status': status, 'skills': skills, 'experience_level': level, 'city': city, if (github != null) 'github_url': github, 'status': 'Тестовый бот'});
  if ((res['status'] as int) >= 400) fail('patch card', res);
}

Future<void> main() async {
  const password = 'MurkotBot123!';
  final rnd = Random(42);
  final skillsPool = ['Flutter','Dart','Python','Go','Rust','React','Vue','Node.js','Kotlin','Swift','C++','Java','SQL','Postgres','Redis','Docker','K8s','AWS','ML','PyTorch','Android','iOS','Unity','Figma','QA','DevOps','Elixir','Haskell','GraphQL','gRPC','Django','FastAPI','Spring','.NET','React Native','Expo','Solidity','Blockchain','AR/VR','Data Science'];
  final cities = ['Москва','Санкт-Петербург','Казань','Новосибирск','Екатеринбург','Алматы','Минск','Warsaw','Berlin','Remote'];
  final statuses = ['looking_for_team','looking_for_members','open_to_offers','do_not_disturb'];
  final levels = ['junior','middle','senior','lead'];
  final emojis = ['😀','🦊','🐱','🐶','🌟','🎮','🎨','🔥','💎','🚀','🌈','🎭','🎵','⚡','🍀','🦄','🐻','🦁','🐼','🐨'];

  stdout.writeln('Seeding 100 bots...');
  for (int i = 1; i <= 100; i++) {
    final login = 'bot_${i.toString().padLeft(3,'0')}';
    final email = 'bot${i.toString().padLeft(3,'0')}.murkot@gmail.com';
    final emoji = emojis[rnd.nextInt(emojis.length)];
    final status = statuses[rnd.nextInt(statuses.length)];
    final level = levels[rnd.nextInt(levels.length)];
    final city = cities[rnd.nextInt(cities.length)];
    final skills = (List<String>.from(skillsPool)..shuffle(rnd)).take(2 + rnd.nextInt(4)).toList();
    final github = rnd.nextBool() ? 'https://github.com/${login}' : null;
    try {
      final token = await ensureSession(email: email, password: password, login: login, emoji: emoji);
      await patchCard(token, status: status, skills: skills, level: level, city: city, github: github);
      stdout.writeln('[$i/100] $login $status ${skills.join(',')} $city');
    } catch (e) {
      stderr.writeln('[$i] $login failed $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  stdout.writeln('DONE 100 bots. Password: $password');
}
