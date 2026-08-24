import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../services/settings_service.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/unlumen/murkot_fx.dart';

/// About / project info — opened from the branded About nav slot.
class AboutMurkotScreen extends StatelessWidget {
  const AboutMurkotScreen({super.key, this.settingsService});

  final SettingsService? settingsService;

  static const _nikitaSite = 'https://nikita-dodiev.vercel.app/en';
  static const _timaSite = 'https://tima-red.vercel.app/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.55,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const MurkotBackButton(),
        title: Text(strings.aboutTitle),
        actions: [
          if (settingsService != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: MurkotThemeSwitch(settings: settingsService!),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        children: [
          const Center(
            child: MurkotBrandImage(
              asset: MurkotAssets.appIconFull,
              width: 240,
            ),
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: 'Murkot',
            delay: const Duration(milliseconds: 80),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          MurkotTextReveal(
            text: strings.aboutTagline,
            delay: const Duration(milliseconds: 220),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: strings.aboutBody1,
            delay: const Duration(milliseconds: 360),
            duration: const Duration(milliseconds: 1100),
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          MurkotTextReveal(
            text: strings.aboutBody2,
            delay: const Duration(milliseconds: 520),
            duration: const Duration(milliseconds: 1200),
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          MurkotTextReveal(
            text: strings.aboutBody3,
            delay: const Duration(milliseconds: 680),
            duration: const Duration(milliseconds: 1200),
            style: bodyStyle,
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: strings.aboutTeam,
            delay: const Duration(milliseconds: 820),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 520;
              final cards = [
                _CreatorCard(
                  name: 'Nikita',
                  role: strings.aboutCreator1Role,
                  photoAsset: 'assets/about/nikita.png',
                  onNameTap: () => _openUrl(_nikitaSite),
                ),
                _CreatorCard(
                  name: 'Tima',
                  role: strings.aboutCreator2Role,
                  photoAsset: 'assets/about/tima.png',
                  onNameTap: () => _openUrl(_timaSite),
                ),
              ];
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 24),
                  cards[1],
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: strings.aboutBody4,
            delay: const Duration(milliseconds: 980),
            duration: const Duration(milliseconds: 1300),
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          MurkotTextReveal(
            text: strings.aboutBody5,
            delay: const Duration(milliseconds: 1140),
            duration: const Duration(milliseconds: 1300),
            style: bodyStyle,
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(strings.isRu ? 'Есть идея?' : 'Have an idea?',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(strings.isRu ? 'Напиши разрабам — предложи улучшение, прикрепи фото если нужно.' : 'Write to the devs — suggest improvements, attach a photo if needed.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openFeedback(context),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(strings.isRu ? 'Предложить улучшение' : 'Suggest improvement'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© Murkot',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openFeedback(BuildContext context) async {
    final auth = AuthService();
    final login = auth.currentUser?.login ?? 'anon';
    final controller = TextEditingController();
    Uint8List? photoBytes;
    String? photoName;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setM) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.strings.isRu ? 'Письмо разрабам' : 'Message to devs', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: controller, minLines: 3, maxLines: 6, maxLength: 2000, decoration: InputDecoration(hintText: context.strings.isRu ? 'Твоя идея...' : 'Your idea...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 8),
                Row(children: [
                  OutlinedButton.icon(onPressed: () async {
                    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
                    if (f != null) { photoBytes = await f.readAsBytes(); photoName = f.name; setM(() {}); }
                  }, icon: const Icon(Icons.image_outlined, size: 18), label: Text(photoBytes == null ? (context.strings.isRu ? 'Фото' : 'Photo') : photoName ?? 'photo')),
                  if (photoBytes != null) IconButton(onPressed: () => setM(() { photoBytes = null; photoName = null; }), icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(context.strings.isRu ? 'Отправить' : 'Send')),
              ],
            ),
          );
        });
      },
    );
    controller.dispose();
    if (picked == null || picked.isEmpty) return;
    String? photoUrl;
    if (photoBytes != null) {
      photoUrl = await FeedbackService().uploadPhoto(login: login, bytes: photoBytes!);
    }
    final err = await FeedbackService().submit(text: picked, photoUrl: photoUrl);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? (context.strings.isRu ? 'Отправлено!' : 'Sent!') : 'Error: $err')));
  }

  void _showSoon(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 72),
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: MurkotColors.brandGradient,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 2200), entry.remove);
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({
    required this.name,
    required this.role,
    required this.photoAsset,
    required this.onNameTap,
  });

  final String name;
  final String role;
  final String photoAsset;
  final VoidCallback onNameTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            photoAsset,
            width: 200,
            height: 240,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onNameTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.35,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
