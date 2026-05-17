import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'storage_service.dart';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _dk(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
DateTime _fromDk(int k) => DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);

enum ImportantDateType { event, birthday, anniversary }

// ── ImportantEvent ────────────────────────────────────────────────────────────

class ImportantEvent {
  final int id;
  final String title;
  final String note;
  final DateTime startDate;
  final DateTime endDate;

  ImportantEvent({
    required this.id,
    required this.title,
    required this.note,
    required DateTime startDate,
    required DateTime endDate,
  })  : startDate = dateOnly(startDate),
        endDate = dateOnly(endDate);

  DateTime get dateValue => startDate;
  String get date => _formatDateRange(startDate, endDate);
  bool isPastFrom(DateTime today) => endDate.isBefore(dateOnly(today));

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'note': note,
        'start': _dk(startDate), 'end': _dk(endDate),
      };

  static ImportantEvent fromJson(Map<String, dynamic> m) => ImportantEvent(
        id: m['id'] as int,
        title: m['title'] as String,
        note: m['note'] as String? ?? '',
        startDate: _fromDk(m['start'] as int),
        endDate: _fromDk(m['end'] as int),
      );
}

// ── BirthdayDate ──────────────────────────────────────────────────────────────

class BirthdayDate {
  final int id;
  final String name;
  final int solarYear, solarMonth, solarDay;
  final int lunarYear, lunarMonth, lunarDay;

  BirthdayDate({
    required this.id, required this.name,
    required this.solarYear, required this.solarMonth, required this.solarDay,
    required this.lunarYear, required this.lunarMonth, required this.lunarDay,
  });

  String get solarDate => '$solarYear年$solarMonth月$solarDay日';
  String get lunarDate => '$lunarYear年$lunarMonth月$lunarDay日';

  DateTime nextBirthdayFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYear = DateTime(base.year, solarMonth, solarDay);
    return thisYear.isBefore(base)
        ? DateTime(base.year + 1, solarMonth, solarDay)
        : thisYear;
  }

  int daysUntilBirthdayFrom(DateTime today) =>
      nextBirthdayFrom(today).difference(dateOnly(today)).inDays;

  int ageFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYear = DateTime(base.year, solarMonth, solarDay);
    final years =
        base.isBefore(thisYear) ? base.year - solarYear - 1 : base.year - solarYear;
    return years < 0 ? 0 : years;
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name,
        'sy': solarYear, 'sm': solarMonth, 'sd': solarDay,
        'ly': lunarYear, 'lm': lunarMonth, 'ld': lunarDay,
      };

  static BirthdayDate fromJson(Map<String, dynamic> m) => BirthdayDate(
        id: m['id'] as int,
        name: m['name'] as String,
        solarYear: m['sy'] as int, solarMonth: m['sm'] as int, solarDay: m['sd'] as int,
        lunarYear: m['ly'] as int, lunarMonth: m['lm'] as int, lunarDay: m['ld'] as int,
      );
}

// ── AnniversaryDate ───────────────────────────────────────────────────────────

class AnniversaryDate {
  final int id;
  final String name;
  final int solarYear, solarMonth, solarDay;
  final int lunarYear, lunarMonth, lunarDay;

  AnniversaryDate({
    required this.id, required this.name,
    required this.solarYear, required this.solarMonth, required this.solarDay,
    required this.lunarYear, required this.lunarMonth, required this.lunarDay,
  });

  String get solarDate => '$solarYear年$solarMonth月$solarDay日';
  String get lunarDate => '$lunarYear年$lunarMonth月$lunarDay日';

  DateTime nextAnniversaryFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYear = DateTime(base.year, solarMonth, solarDay);
    return thisYear.isBefore(base)
        ? DateTime(base.year + 1, solarMonth, solarDay)
        : thisYear;
  }

  int daysUntilAnniversaryFrom(DateTime today) =>
      nextAnniversaryFrom(today).difference(dateOnly(today)).inDays;

  int yearsFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYear = DateTime(base.year, solarMonth, solarDay);
    final completed = base.year - solarYear;
    final years = base.isBefore(thisYear) ? completed - 1 : completed;
    return years < 0 ? 0 : years;
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name,
        'sy': solarYear, 'sm': solarMonth, 'sd': solarDay,
        'ly': lunarYear, 'lm': lunarMonth, 'ld': lunarDay,
      };

  static AnniversaryDate fromJson(Map<String, dynamic> m) => AnniversaryDate(
        id: m['id'] as int,
        name: m['name'] as String,
        solarYear: m['sy'] as int, solarMonth: m['sm'] as int, solarDay: m['sd'] as int,
        lunarYear: m['ly'] as int, lunarMonth: m['lm'] as int, lunarDay: m['ld'] as int,
      );
}

// ── UpcomingImportantDate ─────────────────────────────────────────────────────

class UpcomingImportantDate {
  final ImportantDateType type;
  final int id;
  final String title;
  final String subtitle;
  final DateTime date;
  final String dateText;
  final Color color;

  const UpcomingImportantDate({
    required this.type, required this.id, required this.title,
    required this.subtitle, required this.date,
    required this.dateText, required this.color,
  });

  int daysFrom(DateTime today) => date.difference(dateOnly(today)).inDays;
}

// ── ImportantDateStore ────────────────────────────────────────────────────────

class ImportantDateStore {
  ImportantDateStore._();

  static const _eventsKey = 'events';
  static const _birthdaysKey = 'birthdays';
  static const _anniversariesKey = 'anniversaries';

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static final List<ImportantEvent> _events = [];
  static final List<BirthdayDate> _birthdays = [];
  static final List<AnniversaryDate> _anniversaries = [];

  static List<ImportantEvent> get events => List.unmodifiable(_events);
  static List<BirthdayDate> get birthdays => List.unmodifiable(_birthdays);
  static List<AnniversaryDate> get anniversaries => List.unmodifiable(_anniversaries);

  // ── 加载 ────────────────────────────────────────────────
  static Future<void> load() async {
    await Future.wait([_loadEvents(), _loadBirthdays(), _loadAnniversaries()]);
  }

  static Future<void> _loadEvents() async {
    final raw = StorageService.getString(_eventsKey);
    if (raw == null) {
      _events.addAll([
        ImportantEvent(id: 1, title: '考研报名截止', note: '备好材料',
            startDate: DateTime(2026, 5, 20), endDate: DateTime(2026, 5, 20)),
        ImportantEvent(id: 2, title: '租房合同到期', note: '提前2个月找房',
            startDate: DateTime(2026, 8, 1), endDate: DateTime(2026, 8, 1)),
        ImportantEvent(id: 3, title: '毕业典礼', note: '难忘的一天',
            startDate: DateTime(2025, 6, 12), endDate: DateTime(2025, 6, 12)),
        ImportantEvent(id: 4, title: '体检复查', note: '带上报告',
            startDate: DateTime(2026, 6, 8), endDate: DateTime(2026, 6, 8)),
        ImportantEvent(id: 5, title: '旅行出发', note: '确认行李',
            startDate: DateTime(2026, 7, 3), endDate: DateTime(2026, 7, 5)),
      ]);
      _saveEvents();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _events.addAll(list.map((e) => ImportantEvent.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  static Future<void> _loadBirthdays() async {
    final raw = StorageService.getString(_birthdaysKey);
    if (raw == null) {
      _birthdays.addAll([
        BirthdayDate(id: 1, name: '妈妈',
            solarYear: 1968, solarMonth: 5, solarDay: 23,
            lunarYear: 1968, lunarMonth: 4, lunarDay: 26),
        BirthdayDate(id: 2, name: '爸爸',
            solarYear: 1965, solarMonth: 5, solarDay: 14,
            lunarYear: 1965, lunarMonth: 4, lunarDay: 15),
        BirthdayDate(id: 3, name: '小雨',
            solarYear: 1998, solarMonth: 4, solarDay: 4,
            lunarYear: 1998, lunarMonth: 3, lunarDay: 8),
      ]);
      _saveBirthdays();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _birthdays.addAll(list.map((e) => BirthdayDate.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  static Future<void> _loadAnniversaries() async {
    final raw = StorageService.getString(_anniversariesKey);
    if (raw == null) {
      _anniversaries.addAll([
        AnniversaryDate(id: 1, name: '结婚纪念日',
            solarYear: 2020, solarMonth: 6, solarDay: 18,
            lunarYear: 2020, lunarMonth: 4, lunarDay: 27),
        AnniversaryDate(id: 2, name: '相识纪念日',
            solarYear: 2018, solarMonth: 11, solarDay: 11,
            lunarYear: 2018, lunarMonth: 10, lunarDay: 4),
      ]);
      _saveAnniversaries();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _anniversaries.addAll(
          list.map((e) => AnniversaryDate.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  // ── 保存 ────────────────────────────────────────────────
  static void _saveEvents() {
    StorageService.setString(
        _eventsKey, jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  static void _saveBirthdays() {
    StorageService.setString(
        _birthdaysKey, jsonEncode(_birthdays.map((e) => e.toJson()).toList()));
  }

  static void _saveAnniversaries() {
    StorageService.setString(
        _anniversariesKey,
        jsonEncode(_anniversaries.map((e) => e.toJson()).toList()));
  }

  // ── 写入 ────────────────────────────────────────────────
  static void saveEvent({
    int? id,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String note = '',
  }) {
    final ns = dateOnly(startDate);
    final ne = dateOnly(endDate);
    final next = ImportantEvent(
      id: id ?? DateTime.now().microsecondsSinceEpoch,
      title: title, note: note,
      startDate: ne.isBefore(ns) ? ne : ns,
      endDate: ne.isBefore(ns) ? ns : ne,
    );
    _replaceOrAdd(_events, next.id, next, (x) => x.id == next.id);
    _saveEvents();
    _notify();
  }

  static void saveBirthday({
    int? id, required String name,
    required DateTime solar, DateTime? lunar,
  }) {
    final ld = lunar ?? solar;
    final next = BirthdayDate(
      id: id ?? DateTime.now().microsecondsSinceEpoch, name: name,
      solarYear: solar.year, solarMonth: solar.month, solarDay: solar.day,
      lunarYear: ld.year, lunarMonth: ld.month, lunarDay: ld.day,
    );
    _replaceOrAdd(_birthdays, next.id, next, (x) => x.id == next.id);
    _saveBirthdays();
    _notify();
  }

  static void saveAnniversary({
    int? id, required String name,
    required DateTime solar, DateTime? lunar,
  }) {
    final ld = lunar ?? solar;
    final next = AnniversaryDate(
      id: id ?? DateTime.now().microsecondsSinceEpoch, name: name,
      solarYear: solar.year, solarMonth: solar.month, solarDay: solar.day,
      lunarYear: ld.year, lunarMonth: ld.month, lunarDay: ld.day,
    );
    _replaceOrAdd(_anniversaries, next.id, next, (x) => x.id == next.id);
    _saveAnniversaries();
    _notify();
  }

  static void removeEvent(int id) {
    _events.removeWhere((x) => x.id == id);
    _saveEvents();
    _notify();
  }

  static void removeBirthday(int id) {
    _birthdays.removeWhere((x) => x.id == id);
    _saveBirthdays();
    _notify();
  }

  static void removeAnniversary(int id) {
    _anniversaries.removeWhere((x) => x.id == id);
    _saveAnniversaries();
    _notify();
  }

  static void removeUpcoming(ImportantDateType type, int id) {
    switch (type) {
      case ImportantDateType.event: removeEvent(id);
      case ImportantDateType.birthday: removeBirthday(id);
      case ImportantDateType.anniversary: removeAnniversary(id);
    }
  }

  // ── 查询 ────────────────────────────────────────────────
  static List<UpcomingImportantDate> upcomingWithinMonths({
    required DateTime today, int months = 2,
  }) {
    if (months <= 0) return const [];
    final start = dateOnly(today);
    final end = dateOnly(DateTime(start.year, start.month + months, start.day));
    final items = <UpcomingImportantDate>[];

    for (final ev in _events) {
      if (ev.endDate.isBefore(start) || ev.startDate.isAfter(end)) continue;
      final d = ev.startDate.isBefore(start) ? start : ev.startDate;
      items.add(UpcomingImportantDate(
        type: ImportantDateType.event, id: ev.id,
        title: ev.title, subtitle: ev.note.isEmpty ? '重要事件' : ev.note,
        date: d, dateText: ev.date, color: const Color(0xFFD76F72),
      ));
    }
    for (final b in _birthdays) {
      final d = b.nextBirthdayFrom(start);
      if (d.isAfter(end)) continue;
      items.add(UpcomingImportantDate(
        type: ImportantDateType.birthday, id: b.id,
        title: '${b.name}生日',
        subtitle: '${b.ageFrom(start)}岁 · 阳历 ${b.solarDate}',
        date: d, dateText: '${d.month}月${d.day}日', color: AppColors.birthday,
      ));
    }
    for (final a in _anniversaries) {
      final d = a.nextAnniversaryFrom(start);
      if (d.isAfter(end)) continue;
      items.add(UpcomingImportantDate(
        type: ImportantDateType.anniversary, id: a.id,
        title: a.name,
        subtitle: '第${a.yearsFrom(start)}年 · 阳历 ${a.solarDate}',
        date: d, dateText: '${d.month}月${d.day}日',
        color: const Color(0xFF8B6BAE),
      ));
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  static List<UpcomingImportantDate> allImportantDates({required DateTime today}) {
    final start = dateOnly(today);
    final items = <UpcomingImportantDate>[];
    for (final ev in _events) {
      items.add(UpcomingImportantDate(
        type: ImportantDateType.event, id: ev.id,
        title: ev.title, subtitle: ev.note.isEmpty ? '重要事件' : ev.note,
        date: ev.startDate, dateText: ev.date, color: const Color(0xFFD76F72),
      ));
    }
    for (final b in _birthdays) {
      final d = b.nextBirthdayFrom(start);
      items.add(UpcomingImportantDate(
        type: ImportantDateType.birthday, id: b.id,
        title: '${b.name}生日',
        subtitle: '${b.ageFrom(start)}岁 · 阳历 ${b.solarDate}',
        date: d, dateText: '${d.month}月${d.day}日', color: AppColors.birthday,
      ));
    }
    for (final a in _anniversaries) {
      final d = a.nextAnniversaryFrom(start);
      items.add(UpcomingImportantDate(
        type: ImportantDateType.anniversary, id: a.id,
        title: a.name,
        subtitle: '第${a.yearsFrom(start)}年 · 阳历 ${a.solarDate}',
        date: d, dateText: '${d.month}月${d.day}日',
        color: const Color(0xFF8B6BAE),
      ));
    }
    items.sort((a, b) {
      final aPast = a.date.isBefore(start);
      final bPast = b.date.isBefore(start);
      if (aPast != bPast) return aPast ? 1 : -1;
      return aPast ? b.date.compareTo(a.date) : a.date.compareTo(b.date);
    });
    return items;
  }

  // ── 私有工具 ─────────────────────────────────────────────
  static void _notify() => version.value++;

  static void _replaceOrAdd<T>(
      List<T> list, int id, T next, bool Function(T) test) {
    final idx = list.indexWhere(test);
    if (idx == -1) {
      list.add(next);
    } else {
      list[idx] = next;
    }
  }
}

String _formatDateRange(DateTime start, DateTime end) {
  if (DateUtils.isSameDay(start, end)) {
    return '${start.year}年${start.month}月${start.day}日';
  }
  if (start.year == end.year) {
    return '${start.year}年${start.month}月${start.day}日-${end.month}月${end.day}日';
  }
  return '${start.year}年${start.month}月${start.day}日-'
      '${end.year}年${end.month}月${end.day}日';
}
