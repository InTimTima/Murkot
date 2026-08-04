import 'package:flutter/material.dart';

class ProfileWallpaper {
  const ProfileWallpaper({
    required this.id,
    required this.name,
    required this.gradient,
  });

  final String id;
  final String name;
  final Gradient gradient;

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
      id: 'sunset',
      name: 'Мандарин',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB347), Color(0xFFE07010)],
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
      id: 'night',
      name: 'Ночь',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A1A0C), Color(0xFF5A3010)],
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
  ];

  static ProfileWallpaper byId(String id) {
    return presets.firstWhere(
      (w) => w.id == id,
      orElse: () => presets.first,
    );
  }
}
