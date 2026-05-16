import 'package:flutter/material.dart';

import 'app_colors.dart';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

enum ImportantDateType { event, birthday, anniversary }

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
}

class BirthdayDate {
  final int id;
  final String name;
  final int solarYear;
  final int solarMonth;
  final int solarDay;
  final int lunarYear;
  final int lunarMonth;
  final int lunarDay;

  BirthdayDate({
    required this.id,
    required this.name,
    required this.solarYear,
    required this.solarMonth,
    required this.solarDay,
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
  });

  String get solarDate => '$solarYear年$solarMonth月$solarDay日';
  String get lunarDate => '$lunarYear年$lunarMonth月$lunarDay日';

  DateTime nextBirthdayFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYearBirthday = DateTime(base.year, solarMonth, solarDay);
    if (thisYearBirthday.isBefore(base)) {
      return DateTime(base.year + 1, solarMonth, solarDay);
    }
    return thisYearBirthday;
  }

  int daysUntilBirthdayFrom(DateTime today) =>
      nextBirthdayFrom(today).difference(dateOnly(today)).inDays;

  int ageFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYearBirthday = DateTime(base.year, solarMonth, solarDay);
    final years = base.isBefore(thisYearBirthday)
        ? base.year - solarYear - 1
        : base.year - solarYear;
    return years < 0 ? 0 : years;
  }
}

class AnniversaryDate {
  final int id;
  final String name;
  final int solarYear;
  final int solarMonth;
  final int solarDay;
  final int lunarYear;
  final int lunarMonth;
  final int lunarDay;

  AnniversaryDate({
    required this.id,
    required this.name,
    required this.solarYear,
    required this.solarMonth,
    required this.solarDay,
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
  });

  String get solarDate => '$solarYear年$solarMonth月$solarDay日';
  String get lunarDate => '$lunarYear年$lunarMonth月$lunarDay日';

  DateTime nextAnniversaryFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYearAnniversary = DateTime(base.year, solarMonth, solarDay);
    if (thisYearAnniversary.isBefore(base)) {
      return DateTime(base.year + 1, solarMonth, solarDay);
    }
    return thisYearAnniversary;
  }

  int daysUntilAnniversaryFrom(DateTime today) =>
      nextAnniversaryFrom(today).difference(dateOnly(today)).inDays;

  int yearsFrom(DateTime today) {
    final base = dateOnly(today);
    final thisYearAnniversary = DateTime(base.year, solarMonth, solarDay);
    final completedYears = base.year - solarYear;
    final years = base.isBefore(thisYearAnniversary)
        ? completedYears - 1
        : completedYears;
    return years < 0 ? 0 : years;
  }
}

class UpcomingImportantDate {
  final ImportantDateType type;
  final int id;
  final String title;
  final String subtitle;
  final DateTime date;
  final String dateText;
  final Color color;

  const UpcomingImportantDate({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.dateText,
    required this.color,
  });

  int daysFrom(DateTime today) => date.difference(dateOnly(today)).inDays;
}

class ImportantDateStore {
  ImportantDateStore._();

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static final List<ImportantEvent> _events = [
    ImportantEvent(
      id: 1,
      title: '考研报名截止',
      note: '备好材料',
      startDate: DateTime(2026, 5, 20),
      endDate: DateTime(2026, 5, 20),
    ),
    ImportantEvent(
      id: 2,
      title: '租房合同到期',
      note: '提前2个月找房',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 1),
    ),
    ImportantEvent(
      id: 3,
      title: '毕业典礼',
      note: '难忘的一天',
      startDate: DateTime(2025, 6, 12),
      endDate: DateTime(2025, 6, 12),
    ),
    ImportantEvent(
      id: 4,
      title: '体检复查',
      note: '带上报告',
      startDate: DateTime(2026, 6, 8),
      endDate: DateTime(2026, 6, 8),
    ),
    ImportantEvent(
      id: 5,
      title: '旅行出发',
      note: '确认行李',
      startDate: DateTime(2026, 7, 3),
      endDate: DateTime(2026, 7, 5),
    ),
  ];

  static final List<BirthdayDate> _birthdays = [
    BirthdayDate(
      id: 1,
      name: '妈妈',
      solarYear: 1968,
      solarMonth: 5,
      solarDay: 23,
      lunarYear: 1968,
      lunarMonth: 4,
      lunarDay: 26,
    ),
    BirthdayDate(
      id: 2,
      name: '爸爸',
      solarYear: 1965,
      solarMonth: 5,
      solarDay: 14,
      lunarYear: 1965,
      lunarMonth: 4,
      lunarDay: 15,
    ),
    BirthdayDate(
      id: 3,
      name: '小雨',
      solarYear: 1998,
      solarMonth: 4,
      solarDay: 4,
      lunarYear: 1998,
      lunarMonth: 3,
      lunarDay: 8,
    ),
  ];

  static final List<AnniversaryDate> _anniversaries = [
    AnniversaryDate(
      id: 1,
      name: '结婚纪念日',
      solarYear: 2020,
      solarMonth: 6,
      solarDay: 18,
      lunarYear: 2020,
      lunarMonth: 4,
      lunarDay: 27,
    ),
    AnniversaryDate(
      id: 2,
      name: '相识纪念日',
      solarYear: 2018,
      solarMonth: 11,
      solarDay: 11,
      lunarYear: 2018,
      lunarMonth: 10,
      lunarDay: 4,
    ),
  ];

  static List<ImportantEvent> get events => List.unmodifiable(_events);
  static List<BirthdayDate> get birthdays => List.unmodifiable(_birthdays);
  static List<AnniversaryDate> get anniversaries =>
      List.unmodifiable(_anniversaries);

  static void saveEvent({
    int? id,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String note = '',
  }) {
    final normalizedStart = dateOnly(startDate);
    final normalizedEnd = dateOnly(endDate);
    final next = ImportantEvent(
      id: id ?? DateTime.now().microsecondsSinceEpoch,
      title: title,
      note: note,
      startDate: normalizedEnd.isBefore(normalizedStart)
          ? normalizedEnd
          : normalizedStart,
      endDate: normalizedEnd.isBefore(normalizedStart)
          ? normalizedStart
          : normalizedEnd,
    );
    _replaceOrAddEvent(next, id);
    _notify();
  }

  static void saveBirthday({
    int? id,
    required String name,
    required DateTime solar,
    DateTime? lunar,
  }) {
    final lunarDate = lunar ?? solar;
    final next = BirthdayDate(
      id: id ?? DateTime.now().microsecondsSinceEpoch,
      name: name,
      solarYear: solar.year,
      solarMonth: solar.month,
      solarDay: solar.day,
      lunarYear: lunarDate.year,
      lunarMonth: lunarDate.month,
      lunarDay: lunarDate.day,
    );
    _replaceOrAddBirthday(next, id);
    _notify();
  }

  static void saveAnniversary({
    int? id,
    required String name,
    required DateTime solar,
    DateTime? lunar,
  }) {
    final lunarDate = lunar ?? solar;
    final next = AnniversaryDate(
      id: id ?? DateTime.now().microsecondsSinceEpoch,
      name: name,
      solarYear: solar.year,
      solarMonth: solar.month,
      solarDay: solar.day,
      lunarYear: lunarDate.year,
      lunarMonth: lunarDate.month,
      lunarDay: lunarDate.day,
    );
    _replaceOrAddAnniversary(next, id);
    _notify();
  }

  static void removeEvent(int id) {
    _events.removeWhere((x) => x.id == id);
    _notify();
  }

  static void removeBirthday(int id) {
    _birthdays.removeWhere((x) => x.id == id);
    _notify();
  }

  static void removeAnniversary(int id) {
    _anniversaries.removeWhere((x) => x.id == id);
    _notify();
  }

  static void removeUpcoming(ImportantDateType type, int id) {
    switch (type) {
      case ImportantDateType.event:
        removeEvent(id);
        break;
      case ImportantDateType.birthday:
        removeBirthday(id);
        break;
      case ImportantDateType.anniversary:
        removeAnniversary(id);
        break;
    }
  }

  static List<UpcomingImportantDate> upcomingWithinMonths({
    required DateTime today,
    int months = 2,
  }) {
    if (months <= 0) return const [];

    final start = dateOnly(today);
    final end = dateOnly(DateTime(start.year, start.month + months, start.day));
    final items = <UpcomingImportantDate>[];

    for (final event in _events) {
      if (event.endDate.isBefore(start) || event.startDate.isAfter(end)) {
        continue;
      }
      final displayDate =
          event.startDate.isBefore(start) ? start : event.startDate;
      items.add(UpcomingImportantDate(
        type: ImportantDateType.event,
        id: event.id,
        title: event.title,
        subtitle: event.note.isEmpty ? '重要事件' : event.note,
        date: displayDate,
        dateText: event.date,
        color: const Color(0xFFD76F72),
      ));
    }

    for (final birthday in _birthdays) {
      final date = birthday.nextBirthdayFrom(start);
      if (date.isAfter(end)) continue;
      items.add(UpcomingImportantDate(
        type: ImportantDateType.birthday,
        id: birthday.id,
        title: '${birthday.name}生日',
        subtitle: '${birthday.ageFrom(start)}岁 · 阳历 ${birthday.solarDate}',
        date: date,
        dateText: '${date.month}月${date.day}日',
        color: AppColors.birthday,
      ));
    }

    for (final anniversary in _anniversaries) {
      final date = anniversary.nextAnniversaryFrom(start);
      if (date.isAfter(end)) continue;
      items.add(UpcomingImportantDate(
        type: ImportantDateType.anniversary,
        id: anniversary.id,
        title: anniversary.name,
        subtitle:
            '第${anniversary.yearsFrom(start)}年 · 阳历 ${anniversary.solarDate}',
        date: date,
        dateText: '${date.month}月${date.day}日',
        color: const Color(0xFF8B6BAE),
      ));
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  static List<UpcomingImportantDate> allImportantDates({
    required DateTime today,
  }) {
    final start = dateOnly(today);
    final items = <UpcomingImportantDate>[];

    for (final event in _events) {
      items.add(UpcomingImportantDate(
        type: ImportantDateType.event,
        id: event.id,
        title: event.title,
        subtitle: event.note.isEmpty ? '重要事件' : event.note,
        date: event.startDate,
        dateText: event.date,
        color: const Color(0xFFD76F72),
      ));
    }

    for (final birthday in _birthdays) {
      final date = birthday.nextBirthdayFrom(start);
      items.add(UpcomingImportantDate(
        type: ImportantDateType.birthday,
        id: birthday.id,
        title: '${birthday.name}生日',
        subtitle: '${birthday.ageFrom(start)}岁 · 阳历 ${birthday.solarDate}',
        date: date,
        dateText: '${date.month}月${date.day}日',
        color: AppColors.birthday,
      ));
    }

    for (final anniversary in _anniversaries) {
      final date = anniversary.nextAnniversaryFrom(start);
      items.add(UpcomingImportantDate(
        type: ImportantDateType.anniversary,
        id: anniversary.id,
        title: anniversary.name,
        subtitle:
            '第${anniversary.yearsFrom(start)}年 · 阳历 ${anniversary.solarDate}',
        date: date,
        dateText: '${date.month}月${date.day}日',
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

  static void _notify() {
    version.value++;
  }

  static void _replaceOrAddEvent(ImportantEvent next, int? id) {
    if (id == null) {
      _events.add(next);
      return;
    }
    final index = _events.indexWhere((x) => x.id == next.id);
    if (index == -1) {
      _events.add(next);
    } else {
      _events[index] = next;
    }
  }

  static void _replaceOrAddBirthday(BirthdayDate next, int? id) {
    if (id == null) {
      _birthdays.add(next);
      return;
    }
    final index = _birthdays.indexWhere((x) => x.id == next.id);
    if (index == -1) {
      _birthdays.add(next);
    } else {
      _birthdays[index] = next;
    }
  }

  static void _replaceOrAddAnniversary(AnniversaryDate next, int? id) {
    if (id == null) {
      _anniversaries.add(next);
      return;
    }
    final index = _anniversaries.indexWhere((x) => x.id == next.id);
    if (index == -1) {
      _anniversaries.add(next);
    } else {
      _anniversaries[index] = next;
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
  return '${start.year}年${start.month}月${start.day}日-${end.year}年${end.month}月${end.day}日';
}
