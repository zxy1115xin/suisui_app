import 'package:flutter/foundation.dart';

class TodoItem {
  final int id;
  final String text;

  const TodoItem({required this.id, required this.text});
}

class TodoStore {
  TodoStore._();

  static final ValueNotifier<List<TodoItem>> items =
      ValueNotifier<List<TodoItem>>([
    const TodoItem(id: 1, text: '给妈妈买礼物'),
    const TodoItem(id: 2, text: '预约牙医复查'),
    const TodoItem(id: 3, text: '整理换季衣物'),
    const TodoItem(id: 4, text: '补充维生素'),
    const TodoItem(id: 5, text: '整理本周账单'),
  ]);

  static void add(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    items.value = [
      ...items.value,
      TodoItem(id: DateTime.now().millisecondsSinceEpoch, text: value),
    ];
  }

  static void update(int id, String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    items.value = [
      for (final item in items.value)
        if (item.id == id) TodoItem(id: id, text: value) else item,
    ];
  }

  static void remove(int id) {
    items.value = [
      for (final item in items.value)
        if (item.id != id) item,
    ];
  }
}
