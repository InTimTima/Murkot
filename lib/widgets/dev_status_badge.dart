import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/user.dart';
import 'dev_card.dart';

/// Pulsing availability badge inspired by "● доступен для проектов".
class DevStatusBadge extends StatefulWidget {
  const DevStatusBadge({
    super.key,
    required this.status,
    this.large = false,
  });

  final DevStatus status;
  final bool large;

  @override
  State<DevStatusBadge> createState() => _DevStatusBadgeState();
}

class _DevStatusBadgeState extends State<DevStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.status != DevStatus.none) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DevStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == DevStatus.none) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == DevStatus.none) {
      return const SizedBox.shrink();
    }

    final strings = context.strings;
    final theme = Theme.of(context);
    final color = devStatusColor(widget.status, theme.colorScheme);
    final label = availabilityLabel(strings, widget.status);
    final padH = widget.large ? 14.0 : 10.0;
    final padV = widget.large ? 8.0 : 5.0;
    final dot = widget.large ? 9.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_pulse.value);
              return Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.55 + t * 0.45),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25 + t * 0.35),
                      blurRadius: 4 + t * 6,
                      spreadRadius: t * 1.5,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: (widget.large
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.bodySmall)
                  ?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short "availability" line for the status badge.
String availabilityLabel(AppStrings strings, DevStatus status) {
  switch (status) {
    case DevStatus.none:
      return strings.devStatusNone;
    case DevStatus.lookingForTeam:
      return strings.availabilityLookingForTeam;
    case DevStatus.lookingForMembers:
      return strings.availabilityLookingForMembers;
    case DevStatus.openToOffers:
      return strings.availabilityOpenToOffers;
  }
}
