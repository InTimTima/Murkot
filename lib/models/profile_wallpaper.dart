import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/murkot_decor.dart';

class ProfileWallpaper {
  const ProfileWallpaper({
    required this.id,
    required this.name,
    required this.gradient,
    this.ornamentAsset,
  });

  final String id;
  final String name;
  final Gradient gradient;

  /// Optional brand ornament SVG (7–9) drawn over the gradient.
  final String? ornamentAsset;

  static const presets = [
    ProfileWallpaper(
      id: 'blue', // legacy id kept for existing profiles
      name: 'Сок',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFCBF34), Color(0xFFF1891E)],
      ),
    ),
    ProfileWallpaper(
      id: 'cream',
      name: 'Сливки',
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFBF3), Color(0xFFFFE2A8)],
      ),
    ),
    ProfileWallpaper(
      id: 'forest',
      name: 'Листва',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8FBF5A), Color(0xFF5A8F3C)],
      ),
    ),
    ProfileWallpaper(
      id: 'pink',
      name: 'Персик',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFC3A0), Color(0xFFFF8E53)],
      ),
    ),
    ProfileWallpaper(
      id: 'berry',
      name: 'Ягода',
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFF9AA2), Color(0xFFE07010)],
      ),
    ),
    ProfileWallpaper(
      id: 'sky',
      name: 'Небо',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7EC8E3), Color(0xFF3A8FB7)],
      ),
    ),
    ProfileWallpaper(
      id: 'mint',
      name: 'Мята',
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB8E0D2), Color(0xFF5FA8A0)],
      ),
    ),
    ProfileWallpaper(
      id: 'cocoa',
      name: 'Какао',
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5A3A22), Color(0xFF2A1A0C)],
      ),
    ),
    ProfileWallpaper(
      id: 'drops',
      name: 'Капли',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE8B8), Color(0xFFF1891E)],
      ),
      ornamentAsset: MurkotAssets.drops,
    ),
    ProfileWallpaper(
      id: 'circles',
      name: 'Круги',
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFFF0C8), Color(0xFFFCBF34)],
      ),
      ornamentAsset: MurkotAssets.circles,
    ),
    ProfileWallpaper(
      id: 'citrus',
      name: 'Цитрус',
      gradient: RadialGradient(
        center: Alignment(-0.2, -0.3),
        radius: 1.15,
        colors: [Color(0xFFFFF6E8), Color(0xFFFCBF34), Color(0xFFE07010)],
      ),
      ornamentAsset: MurkotAssets.citrus,
    ),
  ];

  static ProfileWallpaper byId(String id) {
    return presets.firstWhere(
      (w) => w.id == id,
      orElse: () => presets.first,
    );
  }
}

/// Renders [ProfileWallpaper] gradient + optional ornament.
class ProfileWallpaperSurface extends StatelessWidget {
  const ProfileWallpaperSurface({
    super.key,
    required this.wallpaper,
    this.borderRadius,
    this.ornamentOpacity = 0.4,
    this.ornamentSize = 120,
  });

  final ProfileWallpaper wallpaper;
  final BorderRadius? borderRadius;
  final double ornamentOpacity;
  final double ornamentSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: wallpaper.gradient),
          ),
          if (wallpaper.ornamentAsset != null)
            Positioned(
              right: -ornamentSize * 0.15,
              bottom: -ornamentSize * 0.1,
              child: Opacity(
                opacity: ornamentOpacity,
                child: SvgPicture.asset(
                  wallpaper.ornamentAsset!,
                  width: ornamentSize,
                  height: ornamentSize,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
