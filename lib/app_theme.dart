import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'storage_service.dart';

const appThemePalettes = [
  AppThemePalette('暖橙', AppColors.brand, AppColors.brandLight),
  AppThemePalette('薄荷', Color(0xFF5AAF8C), Color(0xFFC8E8DC)),
  AppThemePalette('玫瑰', Color(0xFFC4607A), Color(0xFFF5C8D8)),
  AppThemePalette('藤紫', Color(0xFF8B6BAE), Color(0xFFE2D5F0)),
  AppThemePalette('天蓝', Color(0xFF4A8FB5), Color(0xFFC8E0F0)),
];

class AppThemePalette {
  final String name;
  final Color brand;
  final Color light;

  const AppThemePalette(this.name, this.brand, this.light);
}

class AppThemeController {
  AppThemeController._();

  static const _key = 'theme_index';

  static final ValueNotifier<int> index = ValueNotifier<int>(0);

  static AppThemePalette get palette => appThemePalettes[index.value];

  static Future<void> load() async {
    final saved = StorageService.getInt(_key);
    if (saved != null && saved >= 0 && saved < appThemePalettes.length) {
      index.value = saved;
    }
  }

  static void select(int value) {
    if (value < 0 || value >= appThemePalettes.length) return;
    index.value = value;
    StorageService.setInt(_key, value);
  }
}
