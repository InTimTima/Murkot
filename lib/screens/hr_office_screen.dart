import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/billing_service.dart';
import '../services/people_service.dart';
import '../widgets/avatar_display.dart';
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
  String _lang = '';
  String _grade = '';
  String _city = '';
  List<String> _aiResult = [];
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _hasAccess = widget.billingService?.hasHrOffice ?? false;
  }

  void _runAi() {
    final ps = widget.peopleService;
    if (ps == null) {
      setState(() => _aiResult = ['demo_anna','demo_boris','bot_001','bot_002']);
      return;
    }
    final text = _vacancyCtrl.text.toLowerCase();
    final hits = ps.people.where((p) {
      if (text.contains('flutter') && !p.skills.any((s) => s.toLowerCase().contains('flutter'))) return false;
      if (text.contains('python') && !p.skills.any((s) => s.toLowerCase().contains('python'))) return false;
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
              FilledButton.icon(onPressed: () async { await (widget.billingService ?? BillingService()).purchase(MurkotProduct.hrOffice); setState(() => _hasAccess = true); }, icon: const Icon(Icons.workspace_premium), label: Text(strings.isRu ? 'Подключить HR' : 'Unlock HR')),
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
                Wrap(spacing: 8, children: [
                  DropdownButton<String>(value: _lang.isEmpty ? null : _lang, hint: const Text('Язык'), items: const [DropdownMenuItem(value: 'Flutter', child: Text('Flutter')), DropdownMenuItem(value: 'Python', child: Text('Python'))], onChanged: (v) => setState(() => _lang = v ?? '')),
                  DropdownButton<String>(value: _grade.isEmpty ? null : _grade, hint: const Text('Грейд'), items: const [DropdownMenuItem(value: 'junior', child: Text('Junior')), DropdownMenuItem(value: 'middle', child: Text('Middle')), DropdownMenuItem(value: 'senior', child: Text('Senior'))], onChanged: (v) => setState(() => _grade = v ?? '')),
                ]),
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
