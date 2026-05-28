import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

DateTime healthDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

int _dateKey(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

DateTime _dateFromKey(int key) =>
    DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

class FitnessRecordData {
  final DateTime date;
  final String type;
  final int minutes;

  FitnessRecordData({
    required DateTime date,
    required this.type,
    required this.minutes,
  }) : date = healthDateOnly(date);

  Map<String, dynamic> toJson() =>
      {'dk': _dateKey(date), 'type': type, 'min': minutes};

  static FitnessRecordData fromJson(Map<String, dynamic> m) =>
      FitnessRecordData(
        date: _dateFromKey(m['dk'] as int),
        type: m['type'] as String,
        minutes: m['min'] as int,
      );
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': _dateKey(start),
        'end': _dateKey(end),
        'cycle': cycle,
      };

  static PeriodRecordData fromJson(Map<String, dynamic> m) {
    final sk = m['start'] as int;
    final ek = m['end'] as int;
    return PeriodRecordData(
      id: m['id'] as int,
      start: _dateFromKey(sk),
      end: _dateFromKey(ek),
      cycle: m['cycle'] as int,
    );
  }
}

class HealthStore {
  HealthStore._();

  static const _fitnessKey = 'fitness';
  static const _periodKey = 'periods';

  static final ValueNotifier<Map<int, FitnessRecordData>> fitnessRecords =
      ValueNotifier<Map<int, FitnessRecordData>>({});

  static final ValueNotifier<List<PeriodRecordData>> periodRecords =
      ValueNotifier<List<PeriodRecordData>>([]);

  // ── 加载 ──────────────────────────────────────────────
  static Future<void> load() async {
    await Future.wait([_loadFitness(), _loadPeriods()]);
  }

  static Future<void> _loadFitness() async {
    final raw = StorageService.getString(_fitnessKey);
    if (raw == null) {
      fitnessRecords.value = {
        for (final e in _initialFitnessLog.entries)
          _dateKey(DateTime(2026, 5, e.key)): FitnessRecordData(
              date: DateTime(2026, 5, e.key),
              type: e.value.$1,
              minutes: e.value.$2),
      };
      _saveFitness();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final map = <int, FitnessRecordData>{};
      for (final e in list) {
        final rec = FitnessRecordData.fromJson(e as Map<String, dynamic>);
        map[_dateKey(rec.date)] = rec;
      }
      fitnessRecords.value = map;
    } catch (_) {
      fitnessRecords.value = {};
    }
  }

  static Future<void> _loadPeriods() async {
    final raw = StorageService.getString(_periodKey);
    if (raw == null) {
      periodRecords.value = [
        PeriodRecordData(id: 4, start: DateTime(2026, 4, 26), end: DateTime(2026, 4, 30), cycle: 31),
        PeriodRecordData(id: 1, start: DateTime(2026, 3, 26), end: DateTime(2026, 3, 31), cycle: 28),
        PeriodRecordData(id: 2, start: DateTime(2026, 2, 26), end: DateTime(2026, 3, 3), cycle: 28),
        PeriodRecordData(id: 3, start: DateTime(2026, 1, 29), end: DateTime(2026, 2, 4), cycle: 29),
      ];
      _savePeriods();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      periodRecords.value = list
          .map((e) => PeriodRecordData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      periodRecords.value = [];
    }
  }

  // ── 保存 ──────────────────────────────────────────────
  static void _saveFitness() {
    StorageService.setString(
        _fitnessKey, jsonEncode(fitnessRecords.value.values.map((r) => r.toJson()).toList()));
  }

  static void _savePeriods() {
    StorageService.setString(
        _periodKey, jsonEncode(periodRecords.value.map((r) => r.toJson()).toList()));
  }

  // ── 查询 ──────────────────────────────────────────────
  static List<PeriodRecordData> periodRecordsSorted() {
    return [...periodRecords.value]..sort((a, b) => b.start.compareTo(a.start));
  }

  static Map<int, FitnessRecordData> fitnessLogForMonth(int year, int month) {
    final result = <int, FitnessRecordData>{};
    for (final rec in fitnessRecords.value.values) {
      if (rec.date.year == year && rec.date.month == month) {
        result[rec.date.day] = rec;
      }
    }
    return result;
  }

  static FitnessRecordData? fitnessRecordForDate(DateTime date) {
    return fitnessRecords.value[_dateKey(healthDateOnly(date))];
  }

  static int fitnessDaysInYear(int year) {
    return fitnessRecords.value.values
        .where((r) => r.date.year == year)
        .map((r) => _dateKey(r.date))
        .toSet()
        .length;
  }

  static int fitnessMinutesInMonth(int year, int month) {
    return fitnessRecords.value.values
        .where((r) => r.date.year == year && r.date.month == month)
        .fold(0, (sum, r) => sum + r.minutes);
  }

  static int fitnessMinutesInYear(int year) {
    return fitnessRecords.value.values
        .where((r) => r.date.year == year)
        .fold(0, (sum, r) => sum + r.minutes);
  }

  static bool isPeriodDay(DateTime date) {
    final target = healthDateOnly(date);
    for (final rec in periodRecords.value) {
      if (!target.isBefore(rec.start) && !target.isAfter(rec.end)) return true;
    }
    return false;
  }

  // ── 写入 ──────────────────────────────────────────────
  static void saveFitnessRecord({
    required DateTime date,
    required String type,
    required int minutes,
  }) {
    final normalized = healthDateOnly(date);
    fitnessRecords.value = {
      ...fitnessRecords.value,
      _dateKey(normalized): FitnessRecordData(date: normalized, type: type, minutes: minutes),
    };
    _saveFitness();
  }

  static void removeFitnessRecord(DateTime date) {
    final next = {...fitnessRecords.value};
    next.remove(_dateKey(healthDateOnly(date)));
    fitnessRecords.value = next;
    _saveFitness();
  }

  static void savePeriod({
    int? id,
    required DateTime start,
    required DateTime end,
    required int cycle,
  }) {
    final ns = healthDateOnly(start);
    final ne = healthDateOnly(end);
    final record = PeriodRecordData(
      id: id ?? DateTime.now().microsecondsSinceEpoch,
      start: ne.isBefore(ns) ? ne : ns,
      end: ne.isBefore(ns) ? ns : ne,
      cycle: cycle,
    );
    final next = [...periodRecords.value];
    final idx = next.indexWhere((x) => x.id == record.id);
    if (idx >= 0) {
      next[idx] = record;
    } else {
      next.insert(0, record);
    }
    next.sort((a, b) => b.start.compareTo(a.start));
    periodRecords.value = next;
    _savePeriods();
  }

  static void removePeriod(int id) {
    periodRecords.value = [
      for (final r in periodRecords.value)
        if (r.id != id) r,
    ];
    _savePeriods();
  }
}

const _initialFitnessLog = <int, (String, int)>{
  3: ('跑步', 30), 7: ('瑜伽', 45), 10: ('力量', 60),
  14: ('骑行', 90), 17: ('跑步', 45), 20: ('跑步', 60),
  21: ('瑜伽', 45), 23: ('力量', 80), 24: ('跑步', 30),
};
