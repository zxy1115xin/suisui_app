import 'package:flutter/foundation.dart';

DateTime healthDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class FitnessRecordData {
  final DateTime date;
  final String type;
  final int minutes;

  FitnessRecordData({
    required DateTime date,
    required this.type,
    required this.minutes,
  }) : date = healthDateOnly(date);
}

class PeriodRecordData {
  final int id;
  final DateTime start;
  final DateTime end;
  final int cycle;

  PeriodRecordData({
    required this.id,
    required DateTime start,
    required DateTime end,
    required this.cycle,
  })  : start = healthDateOnly(start),
        end = healthDateOnly(end);

  int get days => end.difference(start).inDays + 1;
}

class HealthStore {
  HealthStore._();

  static final ValueNotifier<Map<int, FitnessRecordData>> fitnessRecords =
      ValueNotifier<Map<int, FitnessRecordData>>({
    for (final entry in _initialFitnessLog.entries)
      _dateKey(DateTime(2026, 5, entry.key)): FitnessRecordData(
          date: DateTime(2026, 5, entry.key),
          type: entry.value.$1,
          minutes: entry.value.$2),
  });

  static final ValueNotifier<List<PeriodRecordData>> periodRecords =
      ValueNotifier<List<PeriodRecordData>>([
    PeriodRecordData(
        id: 4,
        start: DateTime(2026, 4, 26),
        end: DateTime(2026, 4, 30),
        cycle: 31),
    PeriodRecordData(
        id: 1,
        start: DateTime(2026, 3, 26),
        end: DateTime(2026, 3, 31),
        cycle: 28),
    PeriodRecordData(
        id: 2,
        start: DateTime(2026, 2, 26),
        end: DateTime(2026, 3, 3),
        cycle: 28),
    PeriodRecordData(
        id: 3,
        start: DateTime(2026, 1, 29),
        end: DateTime(2026, 2, 4),
        cycle: 29),
  ]);

  static List<PeriodRecordData> periodRecordsSorted() {
    return [...periodRecords.value]..sort((a, b) => b.start.compareTo(a.start));
  }

  static int _dateKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static Map<int, FitnessRecordData> fitnessLogForMonth(int year, int month) {
    final result = <int, FitnessRecordData>{};
    for (final record in fitnessRecords.value.values) {
      if (record.date.year == year && record.date.month == month) {
        result[record.date.day] = record;
      }
    }
    return result;
  }

  static int fitnessDaysInYear(int year) {
    return fitnessRecords.value.values
        .where((record) => record.date.year == year)
        .map((record) => _dateKey(record.date))
        .toSet()
        .length;
  }

  static int fitnessMinutesInMonth(int year, int month) {
    return fitnessRecords.value.values
        .where(
            (record) => record.date.year == year && record.date.month == month)
        .fold(0, (sum, record) => sum + record.minutes);
  }

  static void saveFitnessRecord({
    required DateTime date,
    required String type,
    required int minutes,
  }) {
    final normalized = healthDateOnly(date);
    fitnessRecords.value = {
      ...fitnessRecords.value,
      _dateKey(normalized): FitnessRecordData(
        date: normalized,
        type: type,
        minutes: minutes,
      ),
    };
  }

  static void removeFitnessRecord(DateTime date) {
    final next = {...fitnessRecords.value};
    next.remove(_dateKey(date));
    fitnessRecords.value = next;
  }

  static void savePeriod({
    int? id,
    required DateTime start,
    required DateTime end,
    required int cycle,
  }) {
    final normalizedStart = healthDateOnly(start);
    final normalizedEnd = healthDateOnly(end);
    final record = PeriodRecordData(
      id: id ?? DateTime.now().millisecondsSinceEpoch,
      start: normalizedEnd.isBefore(normalizedStart)
          ? normalizedEnd
          : normalizedStart,
      end: normalizedEnd.isBefore(normalizedStart)
          ? normalizedStart
          : normalizedEnd,
      cycle: cycle,
    );
    final next = [...periodRecords.value];
    final index = next.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      next[index] = record;
    } else {
      next.insert(0, record);
    }
    next.sort((a, b) => b.start.compareTo(a.start));
    periodRecords.value = next;
  }

  static void removePeriod(int id) {
    periodRecords.value = [
      for (final record in periodRecords.value)
        if (record.id != id) record,
    ];
  }

  static bool isPeriodDay(DateTime date) {
    final target = healthDateOnly(date);
    for (final record in periodRecords.value) {
      if (!target.isBefore(record.start) && !target.isAfter(record.end)) {
        return true;
      }
    }
    return false;
  }
}

const _initialFitnessLog = <int, (String, int)>{
  3: ('跑步', 30),
  7: ('瑜伽', 45),
  10: ('力量', 60),
  14: ('骑行', 90),
  17: ('跑步', 45),
  20: ('跑步', 60),
  21: ('瑜伽', 45),
  23: ('力量', 80),
  24: ('跑步', 30),
};
