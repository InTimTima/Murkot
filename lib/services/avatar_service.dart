import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AvatarService {
  static Future<String> saveAvatar(String login, String sourcePath) async {
    final dir = await _avatarsDir();
    final file = File(sourcePath);
    final destination = File('${dir.path}/${login}_avatar.jpg');

    if (await destination.exists()) {
      await destination.delete();
    }

    await file.copy(destination.path);
    return destination.path;
  }

  static Future<void> deleteAvatar(String login) async {
    final dir = await _avatarsDir();
    final file = File('${dir.path}/${login}_avatar.jpg');
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<Directory> _avatarsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${appDir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    return avatarsDir;
  }
}
