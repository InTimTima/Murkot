import 'dart:async';

import 'package:flutter/material.dart';

import 'murkot_toast.dart';

class _AdItem {
  const _AdItem({required this.text});

  final String text;
}

/// Native ad marquee — scrolls right→left like a bus/TV ticker.
class AdTicker extends StatefulWidget {
  const AdTicker({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<AdTicker> createState() => _AdTickerState();
}

class _AdTickerState extends State<AdTicker> {
  bool _visible = true;
  final _scroll = ScrollController();
  Timer? _timer;
  bool _running = false;

  static const _ads = <_AdItem>[
    _AdItem(
      text: '🔥 Хакатон Murkot × T-Bank — 12–14 сентября, призовой 1.2M ₽',
    ),
    _AdItem(
      text: '🎓 Курс «Flutter Senior за 8 недель» — скидка 30% по промо MURKOT',
    ),
    _AdItem(
      text: '💡 Лекция «Как пройти собес в FAANG» — онлайн, бесплатно',
    ),
  ];

  String get _line {
    final joined = _ads.map((a) => a.text).join('     ·     ');
    // Duplicate so the loop looks continuous.
    return '$joined     ·     $joined     ·     ';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted || _running) return;
    if (!_scroll.hasClients) {
      Future<void>.delayed(const Duration(milliseconds: 120), _start);
      return;
    }
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _scroll.offset + 0.7;
      if (next >= max / 2) {
        _scroll.jumpTo(next - max / 2);
      } else {
        _scroll.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onTap() {
    MurkotToast.show(context, 'Скоро тут что-то будет');
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.campaign_outlined, size: 14, color: muted),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                child: ListView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Center(
                      child: Text(
                        _line,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 14, color: muted),
              tooltip: 'Скрыть',
              onPressed: () {
                setState(() => _visible = false);
                widget.onClose?.call();
              },
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            ),
          ],
        ),
      ),
    );
  }
}
