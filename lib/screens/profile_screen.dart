import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/profile_wallpaper.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.settingsService,
    required this.blacklistService,
  });

  final AuthService authService;
  final SettingsService settingsService;
  final BlacklistService blacklistService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusController = TextEditingController();
  final _statusFocusNode = FocusNode();
  final _picker = ImagePicker();

  bool _isSavingStatus = false;
  bool _isUpdatingAvatar = false;

  @override
  void initState() {
    super.initState();
    _statusController.text = widget.authService.currentUser?.status ?? '';
    _statusFocusNode.addListener(_onStatusFocusChange);
  }

  @override
  void dispose() {
    _statusFocusNode.removeListener(_onStatusFocusChange);
    _statusFocusNode.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _onStatusFocusChange() {
    if (!_statusFocusNode.hasFocus) _saveStatus(showSnackBar: false);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showAvatarOptions() async {
    final strings = context.strings;
    final hasAvatar = widget.authService.currentUser?.avatarPath != null;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.gallery),
              onTap: () => Navigator.pop(context, _AvatarAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(strings.camera),
              onTap: () => Navigator.pop(context, _AvatarAction.camera),
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(strings.removeAvatar,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => Navigator.pop(context, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _AvatarAction.gallery:
        await _pickAndSaveAvatar(ImageSource.gallery);
      case _AvatarAction.camera:
        await _pickAndSaveAvatar(ImageSource.camera);
      case _AvatarAction.remove:
        await _removeAvatar();
    }
  }

  Future<void> _pickAndSaveAvatar(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _isUpdatingAvatar = true);
    final error = await widget.authService.updateAvatar(file.path);
    if (!mounted) return;
    setState(() => _isUpdatingAvatar = false);
    _showMessage(error ?? context.strings.avatarUpdated);
  }

  Future<void> _removeAvatar() async {
    setState(() => _isUpdatingAvatar = true);
    await widget.authService.removeAvatar();
    if (!mounted) return;
    setState(() => _isUpdatingAvatar = false);
    _showMessage(context.strings.avatarRemoved);
  }

  Future<void> _saveStatus({bool showSnackBar = true}) async {
    if (_isSavingStatus) return;
    final currentStatus = widget.authService.currentUser?.status ?? '';
    if (_statusController.text.trim() == currentStatus) return;

    setState(() => _isSavingStatus = true);
    final error = await widget.authService.updateStatus(_statusController.text);
    if (!mounted) return;
    setState(() => _isSavingStatus = false);

    if (error != null) {
      _showMessage(error);
      return;
    }
    _statusController.text = widget.authService.currentUser?.status ?? '';
    if (showSnackBar) _showMessage(context.strings.statusSaved);
  }

  Future<void> _changeLogin() async {
    final strings = context.strings;
    final newLogin = await showTextInputDialog(
      context: context,
      title: strings.changeName,
      hint: strings.changeNameHint,
      initialValue: widget.authService.currentUser!.login,
      validator: (v) => v == null || v.trim().isEmpty ? strings.nameRequired : null,
    );
    if (newLogin == null || !mounted) return;
    final error = await widget.authService.changeLogin(newLogin);
    _showMessage(error ?? strings.nameChanged);
  }

  Future<void> _changeEmail() async {
    final strings = context.strings;
    final newEmail = await showTextInputDialog(
      context: context,
      title: strings.changeEmail,
      hint: strings.changeEmailHint,
      initialValue: widget.authService.currentUser!.email,
      keyboardType: TextInputType.emailAddress,
      validator: (v) => v == null || !v.contains('@') ? strings.nameRequired : null,
    );
    if (newEmail == null || !mounted) return;

    final password = await showTextInputDialog(
      context: context,
      title: strings.passwordHint,
      hint: strings.passwordHint,
      obscureText: true,
      validator: (v) => v == null || v.isEmpty ? strings.passwordRequired : null,
    );
    if (password == null || !mounted) return;

    final error = await widget.authService.changeEmail(newEmail, password);
    _showMessage(error ?? strings.emailChanged);
  }

  Future<void> _pickBirthday() async {
    final user = widget.authService.currentUser!;
    final picked = await showDatePicker(
      context: context,
      initialDate: user.birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: widget.settingsService.locale,
    );
    if (picked != null) {
      await widget.authService.updateBirthday(picked);
    }
  }

  Future<void> _pickWallpaper() async {
    final strings = context.strings;
    final currentId = widget.authService.currentUser?.profileWallpaperId ?? 'blue';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.chooseWallpaper,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ProfileWallpaper.presets.map((wallpaper) {
                  final isSelected = wallpaper.id == currentId &&
                      widget.authService.currentUser?.customWallpaperPath == null;
                  return GestureDetector(
                    onTap: () async {
                      await widget.authService.updateWallpaper(wallpaper.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: wallpaper.gradient,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 3)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(wallpaper.name, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: Text(strings.uploadWallpaper),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _picker.pickImage(source: ImageSource.gallery);
                  if (file == null || !mounted) return;
                  final error = await widget.authService.updateCustomWallpaper(file.path);
                  _showMessage(error ?? strings.avatarUpdated);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.logoutTitle,
      message: strings.logoutMessage,
      confirmLabel: strings.confirmLogout,
    );
    if (confirmed == true) await widget.authService.logout();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDeleteAccountDialog(context);
    if (confirmed && mounted) {
      await widget.authService.deleteAccount();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          settingsService: widget.settingsService,
          blacklistService: widget.blacklistService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.48;

    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) {
        final current = widget.authService.currentUser!;
        final wallpaper = ProfileWallpaper.byId(current.profileWallpaperId);
        final hasCustomWallpaper = current.customWallpaperPath != null &&
            File(current.customWallpaperPath!).existsSync();

        return Stack(
          children: [
            // Фон только сверху и по бокам
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.34,
              child: hasCustomWallpaper
                  ? Image.file(
                      File(current.customWallpaperPath!),
                      fit: BoxFit.cover,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(gradient: wallpaper.gradient),
                    ),
            ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: cardWidth.clamp(280.0, 480.0),
                  margin: const EdgeInsets.only(top: 12),
                  child: Material(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    clipBehavior: Clip.antiAlias,
                    elevation: 6,
                    child: Column(
                      children: [
                        AppBar(
                          title: Text(strings.profile),
                          centerTitle: true,
                          automaticallyImplyLeading: false,
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              tooltip: strings.settingsTitle,
                              onPressed: _openSettings,
                            ),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _AvatarSection(
                                  avatarPath: current.avatarPath,
                                  avatarEmoji: current.avatarEmoji,
                                  login: current.login,
                                  status: current.status,
                                  isLoading: _isUpdatingAvatar,
                                  hint: strings.changeAvatarHint,
                                  onTap: _isUpdatingAvatar ? null : _showAvatarOptions,
                                  onLoginTap: _changeLogin,
                                ),
                                const SizedBox(height: 24),
                                _ProfileField(
                                  icon: Icons.edit_outlined,
                                  label: strings.status,
                                  child: TextField(
                                    controller: _statusController,
                                    focusNode: _statusFocusNode,
                                    maxLength: 120,
                                    decoration: InputDecoration(
                                      hintText: strings.statusHint,
                                      counterText: '',
                                      suffixIcon: _isSavingStatus
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.check),
                                              onPressed: _saveStatus,
                                            ),
                                    ),
                                    onSubmitted: (_) {
                                      _saveStatus();
                                      _statusFocusNode.unfocus();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _ProfileField(
                                  icon: Icons.email_outlined,
                                  label: strings.email,
                                  child: Column(
                                    children: [
                                      _ReadOnlyField(text: current.email),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _changeEmail,
                                          child: Text(strings.changeEmail),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _ProfileField(
                                  icon: Icons.cake_outlined,
                                  label: strings.birthday,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      current.birthday != null
                                          ? '${formatBirthday(current.birthday!)} (${strings.ageYears(calculateAge(current.birthday!))})'
                                          : strings.notSet,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: _pickBirthday,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.wallpaper, color: theme.colorScheme.primary),
                                  title: Text(strings.chooseWallpaper),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _pickWallpaper,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: _logout,
                                  icon: Icon(Icons.logout, color: theme.colorScheme.error),
                                  label: Text(strings.logout,
                                      style: TextStyle(color: theme.colorScheme.error)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 52),
                                    side: BorderSide(
                                        color: theme.colorScheme.error.withOpacity(0.5)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _deleteAccount,
                                  icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                                  label: Text(strings.deleteAccount,
                                      style: TextStyle(color: theme.colorScheme.error)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 52),
                                    side: BorderSide(
                                        color: theme.colorScheme.error.withOpacity(0.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _AvatarAction { gallery, camera, remove }

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarPath,
    required this.avatarEmoji,
    required this.login,
    required this.status,
    required this.isLoading,
    required this.hint,
    required this.onTap,
    required this.onLoginTap,
  });

  final String? avatarPath;
  final String? avatarEmoji;
  final String login;
  final String status;
  final bool isLoading;
  final String hint;
  final VoidCallback? onTap;
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: AvatarDisplay(
                  avatarPath: avatarPath,
                  avatarEmoji: avatarEmoji,
                  name: login,
                  radius: 52,
                ),
              ),
            ),
            if (isLoading)
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onLoginTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(login,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
            ],
          ),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(status,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 4),
        Text(hint,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
