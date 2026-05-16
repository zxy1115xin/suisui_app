import 'package:flutter/foundation.dart';

DateTime get appToday {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class WeightStore {
  WeightStore._();

  static final ValueNotifier<Map<int, double>> weights =
      ValueNotifier<Map<int, double>>({
    for (final entry in _initialWeightHistory.entries)
      dateKey(DateTime(2026, 4, entry.key)): entry.value,
  });

  static double get todayWeight => weightForDate(appToday);

  static int dateKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static DateTime dateFromKey(int key) =>
      DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  static double weightForDate(DateTime date) {
    final values = weights.value;
    final key = dateKey(date);
    if (values[key] != null) return values[key]!;
    final existingKeys = values.keys.toList();
    if (existingKeys.isEmpty) return 52.0;
    existingKeys.sort((a, b) {
      final aDistance = (dateFromKey(a).difference(date).inDays).abs();
      final bDistance = (dateFromKey(b).difference(date).inDays).abs();
      if (aDistance != bDistance) return aDistance.compareTo(bDistance);
      return a.compareTo(b);
    });
    return values[existingKeys.first]!;
  }

  static void setWeight(DateTime date, double value) {
    weights.value = {
      ...weights.value,
      dateKey(date): value,
    };
  }
}

const _initialWeightHistory = <int, double>{
  1: 53.1,
  2: 53.0,
  3: 52.9,
  4: 53.0,
  5: 52.8,
  6: 52.7,
  7: 52.9,
  8: 52.8,
  9: 52.6,
  10: 52.7,
  11: 52.5,
  12: 52.6,
  13: 52.4,
  14: 52.3,
  15: 52.5,
  16: 52.2,
  17: 52.3,
  18: 52.2,
  19: 52.1,
  20: 52.1,
  21: 52.4,
  22: 52.0,
  23: 51.8,
  24: 52.2,
  25: 52.6,
  26: 52.4,
  27: 52.3,
  28: 52.2,
  29: 52.0,
  30: 51.9,
};
