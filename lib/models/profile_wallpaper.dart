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
      id: 'blue',
      name: 'Синий',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5B6CFF), Color(0xFF8B5CF6)],
      ),
    ),
    ProfileWallpaper(
      id: 'sunset',
      name: 'Закат',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
      ),
    ),
    ProfileWallpaper(
      id: 'forest',
      name: 'Лес',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
      ),
    ),
    ProfileWallpaper(
      id: 'night',
      name: 'Ночь',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F2027), Color(0xFF203A43)],
      ),
    ),
    ProfileWallpaper(
      id: 'pink',
      name: 'Розовый',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
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
