import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.settingsService,
  });

  final AuthService authService;
  final SettingsService settingsService;

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
    if (!_statusFocusNode.hasFocus) {
      _saveStatus(showSnackBar: false);
    }
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
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(
                  strings.removeAvatar,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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

    if (error != null) {
      _showMessage(error);
    } else {
      _showMessage(context.strings.avatarUpdated);
    }
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

    if (showSnackBar) {
      _showMessage(context.strings.statusSaved);
    }
  }

  Future<void> _logout() async {
    final strings = context.strings;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.logoutTitle),
        content: Text(strings.logoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.confirmLogout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.authService.logout();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(settingsService: widget.settingsService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profile),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: strings.settings,
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.authService,
        builder: (context, _) {
          final current = widget.authService.currentUser!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _AvatarSection(
                  avatarPath: current.avatarPath,
                  login: current.login,
                  status: current.status,
                  isLoading: _isUpdatingAvatar,
                  hint: strings.changeAvatarHint,
                  onTap: _isUpdatingAvatar ? null : _showAvatarOptions,
                ),
                const SizedBox(height: 32),
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
                              onPressed: () => _saveStatus(),
                            ),
                    ),
                    textInputAction: TextInputAction.done,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReadOnlyField(text: current.email),
                      const SizedBox(height: 6),
                      Text(
                        strings.emailNotVerified,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
                  title: Text(strings.settings),
                  subtitle: Text(
                    '${strings.languageLabel}, ${strings.textSize}, ${strings.theme}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openSettings,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: Icon(Icons.logout, color: theme.colorScheme.error),
                  label: Text(
                    strings.logout,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _AvatarAction { gallery, camera, remove }

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarPath,
    required this.login,
    required this.status,
    required this.isLoading,
    required this.hint,
    required this.onTap,
  });

  final String? avatarPath;
  final String login;
  final String status;
  final bool isLoading;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAvatar = avatarPath != null && File(avatarPath!).existsSync();

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
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: hasAvatar ? FileImage(File(avatarPath!)) : null,
                  child: !hasAvatar
                      ? Text(
                          login.isNotEmpty ? login[0].toUpperCase() : '?',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (isLoading)
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          login,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
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
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
