import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class TodoItem {
  final int id;
  final String text;

  const TodoItem({required this.id, required this.text});

  Map<String, dynamic> toJson() => {'id': id, 'text': text};

  static TodoItem fromJson(Map<String, dynamic> m) =>
      TodoItem(id: m['id'] as int, text: m['text'] as String);
}

class TodoStore {
  TodoStore._();

  static const _key = 'todos';

  static final ValueNotifier<List<TodoItem>> items =
      ValueNotifier<List<TodoItem>>([]);

  static Future<void> load() async {
    final raw = StorageService.getString(_key);
    if (raw == null) {
      // 首次运行，展示示例数据并立即持久化
      items.value = const [
        TodoItem(id: 1, text: '给妈妈买礼物'),
        TodoItem(id: 2, text: '预约牙医复查'),
        TodoItem(id: 3, text: '整理换季衣物'),
        TodoItem(id: 4, text: '补充维生素'),
        TodoItem(id: 5, text: '整理本周账单'),
      ];
      _save();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      items.value =
          list.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      items.value = [];
    }
  }

  static void _save() {
    StorageService.setString(
        _key, jsonEncode(items.value.map((e) => e.toJson()).toList()));
  }

  static void add(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    items.value = [
      ...items.value,
      TodoItem(id: DateTime.now().microsecondsSinceEpoch, text: value),
    ];
    _save();
  }

  static void update(int id, String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    items.value = [
      for (final item in items.value)
        if (item.id == id) TodoItem(id: id, text: value) else item,
    ];
    _save();
  }

  static void remove(int id) {
    items.value = [
      for (final item in items.value)
        if (item.id != id) item,
    ];
    _save();
  }
}
