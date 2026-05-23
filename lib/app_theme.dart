import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'storage_service.dart';

const appThemePalettes = [
  AppThemePalette('暖橙', AppColors.brand, AppColors.brandLight),
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

const fontScaleSteps = [0.9, 0.95, 1.0, 1.1, 1.2];
const fontScaleLabels = ['小', '偏小', '标准', '偏大', '大'];

class AppThemeController {
  AppThemeController._();

  static const _themeKey = 'theme_index';
  static const _fontScaleKey = 'font_scale_index';

  static final ValueNotifier<int> index = ValueNotifier<int>(0);
  static final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);

  static AppThemePalette get palette => appThemePalettes[index.value];

  static int get fontScaleIndex {
    final scale = fontScale.value;
    final idx = fontScaleSteps.indexWhere((s) => (s - scale).abs() < 0.001);
    return idx >= 0 ? idx : 2;
  }

  static Future<void> load() async {
    final savedTheme = StorageService.getInt(_themeKey);
    if (savedTheme != null && savedTheme >= 0 && savedTheme < appThemePalettes.length) {
      index.value = savedTheme;
    }
    final savedScale = StorageService.getInt(_fontScaleKey);
    if (savedScale != null && savedScale >= 0 && savedScale < fontScaleSteps.length) {
      fontScale.value = fontScaleSteps[savedScale];
    }
  }

  static void select(int value) {
    if (value < 0 || value >= appThemePalettes.length) return;
    index.value = value;
    StorageService.setInt(_themeKey, value);
  }

  static void selectFontScale(int idx) {
    if (idx < 0 || idx >= fontScaleSteps.length) return;
    fontScale.value = fontScaleSteps[idx];
    StorageService.setInt(_fontScaleKey, idx);
  }
}
