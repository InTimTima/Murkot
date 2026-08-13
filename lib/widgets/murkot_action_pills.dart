import 'package:flutter/material.dart';

class MurkotActionPill {
  const MurkotActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// Compact oval action row: one pill is centered, several share a single line.
class MurkotActionPillsRow extends StatelessWidget {
  const MurkotActionPillsRow({super.key, required this.pills});

  final List<MurkotActionPill> pills;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: pills.length == 1
            ? Center(child: _pill(context, pills.first, expanded: false))
            : Row(
                children: [
                  for (var i = 0; i < pills.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _pill(context, pills[i], expanded: true),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    MurkotActionPill pill, {
    required bool expanded,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: pill.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(pill.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  pill.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
