import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class ProfileStore {
  ProfileStore._();

  static const _key = 'profile';

  static String avatar = '🌷';
  static String nickname = '岁岁';
  static DateTime birthday = DateTime(1998, 4, 26);
  static double height = 162.0;

  // 任意字段变化后 version++ 触发 UI 重建
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static Future<void> load() async {
    final raw = StorageService.getString(_key);
    if (raw == null) return; // 首次运行，保持默认值
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      avatar = m['avatar'] as String? ?? avatar;
      nickname = m['nickname'] as String? ?? nickname;
      final ms = m['birthdayMs'] as int?;
      if (ms != null) birthday = DateTime.fromMillisecondsSinceEpoch(ms);
      height = (m['height'] as num?)?.toDouble() ?? height;
    } catch (_) {}
  }

  static void save({
    required String newAvatar,
    required String newNickname,
    required DateTime newBirthday,
    required double newHeight,
  }) {
    avatar = newAvatar;
    nickname = newNickname;
    birthday = newBirthday;
    height = newHeight;
    version.value++;
    _persist();
  }

  static void _persist() {
    StorageService.setString(
      _key,
      jsonEncode({
        'avatar': avatar,
        'nickname': nickname,
        'birthdayMs': birthday.millisecondsSinceEpoch,
        'height': height,
      }),
    );
  }
}
