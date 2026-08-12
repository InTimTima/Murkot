import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/brand_theme.dart';
import '../models/conversation.dart';

/// Brand assets from the design sheet (`assets/branding/v2`).
/// Prefer PNG for complex marks — Illustrator SVG CSS often renders black on web.
abstract final class MurkotAssets {
  static const appIcon = 'assets/branding/v2/png/murkot2.1-02.png';
  static const appIconFull = 'assets/branding/v2/png/murkot2-02.png';
  static const authMark = 'assets/branding/v2/png/murkot3.1-02.png';
  static const authLogo = 'assets/branding/v2/png/murkot3-02.png';
  static const stackedMark = 'assets/branding/v2/png/murkot1-02.png';
  static const stretchCat = 'assets/branding/v2/png/murkot4-02.png';
  static const settingsBg = 'assets/branding/v2/png/murkot5.1-02.png';
  static const chatsMark = 'assets/branding/v2/png/murkot6.2-02.png';
  static const groupsMark = 'assets/branding/v2/png/murkot5.2-02.png';
  static const channelsMark = 'assets/branding/v2/png/murkot2.2-02.png';
  static const drops = 'assets/branding/v2/svg/murkot7-02.svg';
  static const circles = 'assets/branding/v2/svg/murkot8-02.svg';
  static const citrus = 'assets/branding/v2/svg/murkot9-02.svg';
  static const wordmark = 'assets/branding/v2/svg/murkot10-02.svg';

  static String sectionMark(ConversationType type) => switch (type) {
        ConversationType.direct => chatsMark,
        ConversationType.group => groupsMark,
        ConversationType.channel => channelsMark,
      };
}

Color murkotDecorTint(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? MurkotColors.cream : MurkotColors.orange;
}

/// Soft decorative circle (fallback ornament).
class SoftCircle extends StatelessWidget {
  const SoftCircle({
    super.key,
    this.size = 80,
    this.color = MurkotColors.orange,
    this.opacity = 0.18,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Raw brand PNG — no ColorFilter, no theme tinting.
class MurkotBrandImage extends StatelessWidget {
  const MurkotBrandImage({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.opacity = 1,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double? width;
  final double? height;
  final double opacity;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Auth / launcher mark — cropped icon (design #3.1).
class MurkotLogoMark extends StatelessWidget {
  const MurkotLogoMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: MurkotBrandImage(
        asset: MurkotAssets.authMark,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Full auth lockup with baked-in MURKOT wordmark (design #3).
class MurkotLogoFull extends StatelessWidget {
  const MurkotLogoFull({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    return MurkotBrandImage(
      asset: MurkotAssets.authLogo,
      width: size,
      fit: BoxFit.contain,
    );
  }
}

/// Stacked cat + MUR/KOT (design #1) — about slot / channel panel.
class MurkotStackedMark extends StatelessWidget {
  const MurkotStackedMark({
    super.key,
    this.size = 48,
    this.opacity = 1,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return MurkotBrandImage(
      asset: MurkotAssets.stackedMark,
      width: size,
      height: size,
      opacity: opacity,
    );
  }
}

/// Stretching cat + MUR/KOT (design #4).
class StretchCatSilhouette extends StatelessWidget {
  const StretchCatSilhouette({
    super.key,
    this.width = 120,
    this.color,
    this.opacity = 1,
  });

  final double width;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return MurkotBrandImage(
      asset: MurkotAssets.stretchCat,
      width: width,
      opacity: opacity,
    );
  }
}

/// Section mark for chats / groups / channels lists & desktop rail.
class MurkotSectionMark extends StatelessWidget {
  const MurkotSectionMark({
    super.key,
    required this.type,
    this.width = 220,
    this.opacity = 1,
  });

  final ConversationType type;
  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return MurkotBrandImage(
      asset: MurkotAssets.sectionMark(type),
      width: width,
      opacity: opacity,
    );
  }
}

/// Citrus half-slice (design #9) — mono ornament, tint OK.
class CitrusSlice extends StatelessWidget {
  const CitrusSlice({
    super.key,
    this.size = 72,
    this.color,
    this.opacity = 0.85,
  });

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? murkotDecorTint(context);
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        MurkotAssets.citrus,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}

/// Bubble / circle cluster (design #8).
class CircleCluster extends StatelessWidget {
  const CircleCluster({
    super.key,
    this.size = 120,
    this.color,
    this.opacity = 0.35,
  });

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? murkotDecorTint(context);
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        MurkotAssets.circles,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}

/// Juice-drop splash (design #7).
class JuiceDrops extends StatelessWidget {
  const JuiceDrops({
    super.key,
    this.size = 80,
    this.color,
    this.opacity = 0.45,
  });

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? murkotDecorTint(context);
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        MurkotAssets.drops,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}

/// Empty / watermark hero for a section — single mark, no stacked cats.
class MurkotEmptyHero extends StatelessWidget {
  const MurkotEmptyHero({
    super.key,
    required this.type,
    this.width = 260,
    this.caption,
  });

  final ConversationType type;
  final double width;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MurkotSectionMark(type: type, width: width),
        if (caption != null) ...[
          const SizedBox(height: 16),
          Text(
            caption!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}

/// Decorative background for auth — rich radial gradient + ornaments.
class MurkotAtmosphere extends StatelessWidget {
  const MurkotAtmosphere({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isDark
                  ? MurkotColors.authGradientDark
                  : MurkotColors.authGradientLight,
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -70,
          child: CircleCluster(size: 260, opacity: isDark ? 0.35 : 0.55),
        ),
        Positioned(
          top: 80,
          left: -70,
          child: CircleCluster(
            size: 200,
            color: isDark ? MurkotColors.cream : MurkotColors.yellow,
            opacity: isDark ? 0.2 : 0.32,
          ),
        ),
        Positioned(
          top: 40,
          left: 40,
          child: JuiceDrops(size: 130, opacity: isDark ? 0.32 : 0.45),
        ),
        Positioned(
          bottom: 20,
          left: -20,
          child: JuiceDrops(size: 160, opacity: isDark ? 0.34 : 0.48),
        ),
        Positioned(
          bottom: 36,
          right: -10,
          child: CitrusSlice(size: 140, opacity: isDark ? 0.42 : 0.62),
        ),
        Positioned(
          top: 180,
          right: 12,
          child: CitrusSlice(size: 72, opacity: isDark ? 0.36 : 0.55),
        ),
        Positioned(
          bottom: 160,
          left: 24,
          child: CircleCluster(size: 90, opacity: isDark ? 0.22 : 0.3),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}
