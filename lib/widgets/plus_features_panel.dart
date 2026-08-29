import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/plus_cosmetics.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/plus_analytics_service.dart';
import '../widgets/avatar_display.dart';
import '../widgets/murkot_toast.dart';
import '../widgets/payment_sheet.dart';
import '../services/billing_service.dart';

/// Plus cosmetics controls + who viewed / saved contacts.
class PlusFeaturesPanel extends StatefulWidget {
  const PlusFeaturesPanel({
    super.key,
    required this.authService,
    required this.billing,
    required this.user,
  });

  final AuthService authService;
  final BillingService billing;
  final User user;

  @override
  State<PlusFeaturesPanel> createState() => _PlusFeaturesPanelState();
}

class _PlusFeaturesPanelState extends State<PlusFeaturesPanel> {
  final _analytics = PlusAnalyticsService();
  List<ProfileVisitor> _views = const [];
  List<ProfileVisitor> _saves = const [];
  bool _loadingInsight = false;

  bool get _plus => widget.user.isPlus || widget.billing.isPlus;

  @override
  void initState() {
    super.initState();
    if (_plus) _loadInsight();
  }

  @override
  void didUpdateWidget(covariant PlusFeaturesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_plus && oldWidget.user.isPlus != widget.user.isPlus) {
      _loadInsight();
    }
  }

  Future<void> _loadInsight() async {
    setState(() => _loadingInsight = true);
    final views = await _analytics.listViews();
    final saves = await _analytics.listContactSaves();
    if (!mounted) return;
    setState(() {
      _views = views;
      _saves = saves;
      _loadingInsight = false;
    });
  }

  Future<void> _setFrame(AvatarFrameId frame) async {
    final err = await widget.authService.updateAvatarFrame(frame);
    if (!mounted) return;
    MurkotToast.show(context, err ?? (context.strings.isRu ? 'Рамка обновлена' : 'Frame updated'));
    setState(() {});
  }

  Future<void> _setNick(String? id) async {
    final err = await widget.authService.updateNickColor(id);
    if (!mounted) return;
    MurkotToast.show(
      context,
      err ?? (context.strings.isRu ? 'Цвет ника сохранён' : 'Nick color saved'),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = context.strings.isRu;
    final user = widget.authService.currentUser ?? widget.user;

    if (!_plus) {
      return Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Murkot Plus — 399 ₽/мес',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isRu
                    ? '• Гиф-аватар • Рамки (звёзды, блеск, волны, цитрус…) • Цвет ника • 5 бустов/сутки • До 15 объявлений • Кто смотрел профиль'
                    : '• GIF avatar • Frames • Nick color • 5 boosts/day • 15 listings • Profile viewers',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await showPaymentSheet(
                    context,
                    product: MurkotProduct.plusMonthly,
                    billing: widget.billing,
                  );
                  if (ok) {
                    await widget.authService.refreshPlusFromServer();
                    if (mounted) {
                      setState(() {});
                      _loadInsight();
                    }
                  }
                },
                icon: const Icon(Icons.star),
                label: Text(isRu ? 'Купить Plus' : 'Get Plus'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRu
                            ? 'Murkot Plus активен${user.plusUntil != null ? ' до ${user.plusUntil!.day}.${user.plusUntil!.month}' : ''}'
                            : 'Murkot Plus active',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isRu ? 'Рамка аватара' : 'Avatar frame',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final frame in AvatarFrameId.values)
                      ChoiceChip(
                        avatar: Icon(frame.icon, size: 16),
                        label: Text(frame.title(isRu)),
                        selected: user.avatarFrame == frame,
                        onSelected: (_) => _setFrame(frame),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isRu ? 'Цвет ника' : 'Nick color',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(isRu ? 'По умолчанию' : 'Default'),
                      selected: user.nickColorId == null,
                      onSelected: (_) => _setNick(null),
                    ),
                    for (final opt in kNickColorOptions)
                      ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: opt.color,
                          radius: 8,
                        ),
                        label: Text(
                          opt.title(isRu),
                          style: TextStyle(
                            color: user.nickColorId == opt.id ? opt.color : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: user.nickColorId == opt.id,
                        onSelected: (_) => _setNick(opt.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isRu
                      ? 'Гиф-аватар: в меню аватара выбери «Галерея» и загрузи .gif'
                      : 'GIF avatar: open avatar menu → Gallery and pick a .gif',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      isRu ? 'Кто смотрел профиль' : 'Profile viewers',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _loadInsight,
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
                if (_loadingInsight)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_views.isEmpty)
                  Text(
                    isRu ? 'Пока никто не заходил' : 'No viewers yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  )
                else
                  for (final v in _views.take(12))
                    _VisitorTile(visitor: v, isRu: isRu),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.bookmark_added_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      isRu ? 'Кто сохранял контакты' : 'Contact saves',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_saves.isEmpty)
                  Text(
                    isRu ? 'Пока пусто' : 'Nothing yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  )
                else
                  for (final v in _saves.take(12))
                    _VisitorTile(visitor: v, isRu: isRu, showSource: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitorTile extends StatelessWidget {
  const _VisitorTile({
    required this.visitor,
    required this.isRu,
    this.showSource = false,
  });

  final ProfileVisitor visitor;
  final bool isRu;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nickColor = nickColorFromId(visitor.nickColorId);
    final sourceLabel = switch (visitor.source) {
      'respond' => isRu ? 'отклик' : 'response',
      'airdrop' => isRu ? 'письмо' : 'note',
      'chat' => isRu ? 'чат' : 'chat',
      _ => visitor.source,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: AvatarDisplay(
        name: visitor.login,
        avatarPath: visitor.avatarUrl,
        avatarEmoji: visitor.avatarEmoji,
        frame: visitor.avatarFrame,
        radius: 18,
      ),
      title: Text(
        visitor.login,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: nickColor,
        ),
      ),
      subtitle: Text(
        [
          _rel(visitor.at, isRu),
          if (showSource && sourceLabel != null) sourceLabel,
        ].join(' · '),
        style: theme.textTheme.labelSmall,
      ),
    );
  }

  String _rel(DateTime t, bool isRu) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return isRu ? 'только что' : 'just now';
    if (d.inHours < 1) return isRu ? '${d.inMinutes} мин' : '${d.inMinutes}m';
    if (d.inDays < 1) return isRu ? '${d.inHours} ч' : '${d.inHours}h';
    return isRu ? '${d.inDays} дн' : '${d.inDays}d';
  }
}
