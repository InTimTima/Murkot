import 'package:flutter/material.dart';

class AdTicker extends StatefulWidget {
  const AdTicker({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<AdTicker> createState() => _AdTickerState();
}

class _AdTickerState extends State<AdTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _visible = true;

  final _ads = const [
    '🔥 Хакатон Murkot × T-Bank — 12-14 сентября, призовой 1.2M ₽',
    '🎓 Курс «Flutter Senior за 8 недель» — скидка 30% по промо MURKOT',
    '💡 Лекция «Как пройти собес в FAANG» — онлайн, бесплатно',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      height: 28,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final idx = (_ctrl.value * _ads.length).floor() % _ads.length;
                return Center(
                  child: Text(_ads[idx], style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setState(() => _visible = false), padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 28, height: 28)),
        ],
      ),
    );
  }
}
