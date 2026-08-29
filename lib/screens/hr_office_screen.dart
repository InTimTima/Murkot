import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/billing_service.dart';
import '../services/people_service.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/unlumen/murkot_fx.dart';

class HrOfficeScreen extends StatefulWidget {
  const HrOfficeScreen({super.key, this.peopleService, this.billingService});

  final PeopleService? peopleService;
  final BillingService? billingService;

  @override
  State<HrOfficeScreen> createState() => _HrOfficeScreenState();
}

class _HrOfficeScreenState extends State<HrOfficeScreen> {
  final _queryCtrl = TextEditingController();
  final _vacancyCtrl = TextEditingController();
  String _skill = '';
  String _grade = '';
  String _city = '';
  String _status = '';
  List<String> _aiResult = [];
  List<String> _searchResult = [];
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _hasAccess = widget.billingService?.hasHrOffice ?? false;
    _queryCtrl.addListener(_runSearch);
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _vacancyCtrl.dispose();
    super.dispose();
  }

  void _runSearch() {
    final ps = widget.peopleService;
    if (ps == null) return;
    final q = _queryCtrl.text.toLowerCase().trim();
    final skill = _skill.toLowerCase();
    final city = _city.toLowerCase();
    final grade = _grade.toLowerCase();
    final status = _status.toLowerCase();
    final filtered = ps.people.where((p) {
      if (skill.isNotEmpty && !p.skills.any((s) => s.toLowerCase() == skill || s.toLowerCase().contains(skill))) return false;
      if (city.isNotEmpty && (p.city ?? '').toLowerCase() != city) return false;
      if (grade.isNotEmpty && (p.experienceLevel?.name ?? '').toLowerCase() != grade) return false;
      if (status.isNotEmpty && p.devStatus.name.toLowerCase() != status) return false;
      if (q.isNotEmpty) {
        final hay = '${p.login} ${p.status} ${p.city ?? ''} ${p.skills.join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).take(30).map((p) => p.login).toList();
    setState(() => _searchResult = filtered);
  }

  void _runAi() {
    final ps = widget.peopleService;
    if (ps == null) {
      setState(() => _aiResult = ['demo_anna','demo_boris','bot_001','bot_002']);
      return;
    }
    final text = _vacancyCtrl.text.toLowerCase();
    // Extract all known skills mentioned in vacancy text
    final allSkills = ps.people.expand((p) => p.skills).map((s) => s.toLowerCase()).toSet();
    final mentioned = allSkills.where((s) => text.contains(s)).toList();
    final hits = ps.people.where((p) {
      if (mentioned.isNotEmpty) {
        // At least one mentioned skill must match
        if (!p.skills.any((s) => mentioned.contains(s.toLowerCase()))) return false;
      } else if (text.isNotEmpty) {
        // Fallback: try to match any word from vacancy that equals a skill
        final words = text.split(RegExp(r'[,\s]+'));
        if (!p.skills.any((s) => words.contains(s.toLowerCase()))) {
          // If no skill word matches, do loose contains check
          if (!words.any((w) => p.skills.any((s) => s.toLowerCase().contains(w) || w.contains(s.toLowerCase())))) {
            return false;
          }
        }
      }
      // Also respect selected filters if set
      if (_skill.isNotEmpty && !p.skills.any((s) => s.toLowerCase().contains(_skill.toLowerCase()))) return false;
      if (_city.isNotEmpty && (p.city ?? '').toLowerCase() != _city.toLowerCase()) return false;
      return true;
    }).take(20).map((p) => p.login).toList();
    setState(() => _aiResult = hits);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(leading: const MurkotBackButton(), title: Text(strings.isRu ? 'Кабинет HR' : 'HR Office')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.business_center, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(strings.isRu ? 'Кабинет HR — 24 999 ₽/мес' : 'HR Office — 24 999 RUB/mo', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(strings.isRu ? 'Безлимит поиск, бренд-профиль, Smart-подбор ИИ, рассылка до 20 кандитатов' : 'Unlimited search, branded profile, AI matching, bulk DM', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final billing = widget.billingService ?? BillingService();
                  final ok = await showPaymentSheet(
                    context,
                    product: MurkotProduct.hrOffice,
                    billing: billing,
                  );
                  if (!mounted) return;
                  if (ok) setState(() => _hasAccess = true);
                },
                icon: const Icon(Icons.workspace_premium),
                label: Text(strings.isRu ? 'Подключить HR' : 'Unlock HR'),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const MurkotBackButton(), title: Text(strings.isRu ? 'Кабинет HR' : 'HR Office')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(strings.isRu ? 'Безлимитный поиск' : 'Unlimited search', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(controller: _queryCtrl, decoration: InputDecoration(hintText: strings.peopleSearchHint, prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  DropdownButton<String>(value: _skill.isEmpty ? null : _skill, hint: const Text('Язык/скилл'), items: [
                    const DropdownMenuItem(value: '', child: Text('Любой навык')),
                    for (final s in (widget.peopleService?.availableSkills ?? ['Flutter','Dart','Python','Go','Rust','React','Vue','Node.js','Kotlin','Swift','Java','SQL','Postgres','Docker','K8s','AWS','ML'])) DropdownMenuItem(value: s, child: Text(s)),
                  ], onChanged: (v) { setState(() => _skill = v ?? ''); _runSearch(); }),
                  DropdownButton<String>(value: _grade.isEmpty ? null : _grade, hint: const Text('Грейд'), items: const [DropdownMenuItem(value: '', child: Text('Любой')), DropdownMenuItem(value: 'junior', child: Text('Junior')), DropdownMenuItem(value: 'middle', child: Text('Middle')), DropdownMenuItem(value: 'senior', child: Text('Senior')), DropdownMenuItem(value: 'lead', child: Text('Lead'))], onChanged: (v) { setState(() => _grade = v ?? ''); _runSearch(); }),
                  DropdownButton<String>(value: _city.isEmpty ? null : _city, hint: const Text('Город'), items: [
                    const DropdownMenuItem(value: '', child: Text('Любой город')),
                    for (final c in (widget.peopleService?.availableCities ?? ['Москва','СПб','Казань','Алматы','Remote'])) DropdownMenuItem(value: c, child: Text(c)),
                  ], onChanged: (v) { setState(() => _city = v ?? ''); _runSearch(); }),
                  DropdownButton<String>(value: _status.isEmpty ? null : _status, hint: const Text('Статус'), items: const [DropdownMenuItem(value: '', child: Text('Любой')), DropdownMenuItem(value: 'looking_for_team', child: Text('Ищу команду')), DropdownMenuItem(value: 'looking_for_members', child: Text('Ищу людей')), DropdownMenuItem(value: 'open_to_offers', child: Text('Open to offers')), DropdownMenuItem(value: 'do_not_disturb', child: Text('Не беспокоить'))], onChanged: (v) { setState(() => _status = v ?? ''); _runSearch(); }),
                ]),
                if (_searchResult.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Найдено: ${_searchResult.length}', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [for (final l in _searchResult.take(20)) Chip(label: Text(l))]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(strings.isRu ? 'Брендированный профиль компании' : 'Branded company profile', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(strings.isRu ? 'Логотип, описание, фото офиса, отзывы — формируют HR-бренд' : 'Logo, description, office photos, reviews', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.image_outlined), label: Text(strings.isRu ? 'Загрузить лого' : 'Upload logo')),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Smart-подбор (ИИ)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(controller: _vacancyCtrl, minLines: 3, maxLines: 5, decoration: InputDecoration(hintText: strings.isRu ? 'Вставь текст вакансии: Ищем Middle Flutter, 300к...' : 'Paste vacancy...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _runAi, icon: const Icon(Icons.auto_awesome), label: Text(strings.isRu ? 'Найти 20 кандидатов' : 'Find 20')),
                if (_aiResult.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(strings.isRu ? 'Найдено:' : 'Found:', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [for (final l in _aiResult) Chip(label: Text(l))]),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рассылка до 20 — заглушка'))), icon: const Icon(Icons.send), label: Text(strings.isRu ? 'Разослать до 20' : 'Bulk DM 20')),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
