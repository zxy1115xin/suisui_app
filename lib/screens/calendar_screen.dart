import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lunar/lunar.dart';

import '../app_colors.dart';
import '../health_store.dart';
import '../important_date_store.dart';
import '../todo_store.dart';
import '../weight_store.dart';

// 返回给定公历日期对应的农历日（初一、初二…三十）。
String _lunarDay(DateTime date) =>
    Solar.fromYmd(date.year, date.month, date.day).getLunar().getDayInChinese();

String _lunarYearText(DateTime date) {
  final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();
  return '农历${lunar.getYearInGanZhi()}年';
}

// 日历单元格上的业务事件：生日、节气、普通事件、备注和生理期标记都会汇总到这里。
class _Ev {
  final String? birthday;
  final String? eventName;
  final String? note;
  final bool eventBand;
  final bool eventStart;
  final bool eventEnd;
  final bool period;
  final bool periodStart;
  final bool periodEnd;
  final bool todo;
  final bool todoStart;
  final bool todoEnd;
  const _Ev(
      {this.birthday,
      this.eventName,
      this.note,
      this.eventBand = false,
      this.eventStart = false,
      this.eventEnd = false,
      this.period = false,
      this.periodStart = false,
      this.periodEnd = false,
      this.todo = false,
      this.todoStart = false,
      this.todoEnd = false});
}

// 节假日信息：rest 表示该日期需要显示“休”标记，并用假日颜色突出。
class _Hol {
  final String? name;
  final bool rest;
  final bool work;
  const _Hol({this.name, this.rest = false, this.work = false});
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

// 统一使用北京时间（UTC+8）作为日历“当前时间”来源。
DateTime _beijingNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

// 最多缓存 15 个月的事件数据（足够覆盖年视图 12 格 + 相邻月份）。
// key = "$year/$month/${重要日期版本}/${生理期列表ID}/${待办列表ID}"
final _eventsForMonthCache = <String, Map<int, _Ev>>{};

Map<int, _Ev> _eventsForMonth(int year, int month) {
  final key = '$year/$month'
      '/${ImportantDateStore.version.value}'
      '/${identityHashCode(HealthStore.periodRecords.value)}'
      '/${identityHashCode(TodoStore.items.value)}';
  final cached = _eventsForMonthCache[key];
  if (cached != null) return cached;
  if (_eventsForMonthCache.length >= 15) _eventsForMonthCache.clear();

  final map = <int, _Ev>{};

  void merge(
    DateTime date, {
    String? birthday,
    String? eventName,
    String? note,
    bool eventBand = false,
    bool eventStart = false,
    bool eventEnd = false,
    bool period = false,
    bool periodStart = false,
    bool periodEnd = false,
    bool todo = false,
    bool todoStart = false,
    bool todoEnd = false,
  }) {
    if (date.year != year || date.month != month) return;
    final old = map[date.day];
    map[date.day] = _Ev(
      birthday: birthday ?? old?.birthday,
      eventName: _joinLabel(old?.eventName, eventName),
      note: note ?? old?.note,
      eventBand: eventBand || (old?.eventBand ?? false),
      eventStart: eventStart || (old?.eventStart ?? false),
      eventEnd: eventEnd || (old?.eventEnd ?? false),
      period: period || (old?.period ?? false),
      periodStart: periodStart || (old?.periodStart ?? false),
      periodEnd: periodEnd || (old?.periodEnd ?? false),
      todo: todo || (old?.todo ?? false),
      todoStart: todoStart || (old?.todoStart ?? false),
      todoEnd: todoEnd || (old?.todoEnd ?? false),
    );
  }

  for (final event in ImportantDateStore.events) {
    var day = _dateOnly(event.startDate);
    final last = _dateOnly(event.endDate);
    final spansDays = !DateUtils.isSameDay(event.startDate, event.endDate);
    while (!day.isAfter(last)) {
      merge(
        day,
        eventName: event.title,
        note: event.note,
        eventBand: spansDays,
        eventStart: DateUtils.isSameDay(day, event.startDate),
        eventEnd: DateUtils.isSameDay(day, event.endDate),
      );
      day = day.add(const Duration(days: 1));
    }
  }

  for (final birthday in ImportantDateStore.birthdays) {
    merge(DateTime(year, birthday.solarMonth, birthday.solarDay),
        birthday: '${birthday.name}生日');
  }

  for (final anniversary in ImportantDateStore.anniversaries) {
    merge(DateTime(year, anniversary.solarMonth, anniversary.solarDay),
        eventName: anniversary.name);
  }

  for (final record in HealthStore.periodRecords.value) {
    var day = _dateOnly(record.start);
    final last = _dateOnly(record.end);
    while (!day.isAfter(last)) {
      merge(
        day,
        period: true,
        periodStart: DateUtils.isSameDay(day, record.start),
        periodEnd: DateUtils.isSameDay(day, record.end),
      );
      day = day.add(const Duration(days: 1));
    }
  }

  for (final todo in TodoStore.items.value) {
    final parsed = _parseTodoRange(todo.text, year);
    if (parsed == null) continue;
    var day = _dateOnly(parsed.start);
    final last = _dateOnly(parsed.end);
    while (!day.isAfter(last)) {
      merge(
        day,
        todo: true,
        todoStart: DateUtils.isSameDay(day, parsed.start),
        todoEnd: DateUtils.isSameDay(day, parsed.end),
      );
      day = day.add(const Duration(days: 1));
    }
  }

  _eventsForMonthCache[key] = map;
  return map;
}

String? _joinLabel(String? a, String? b) {
  if (b == null || b.isEmpty) return a;
  if (a == null || a.isEmpty) return b;
  if (a.contains(b)) return a;
  return '$a · $b';
}

class _TodoRange {
  final DateTime start;
  final DateTime end;
  const _TodoRange({required this.start, required this.end});
}

_TodoRange? _parseTodoRange(String text, int defaultYear) {
  final value = text.trim();
  final match = RegExp(
    r'^(?:(\d{4})年)?(\d{1,2})月(\d{1,2})日\s*[-~到]\s*(?:(\d{4})年)?(\d{1,2})月(\d{1,2})日(?:[：:\s]+.*)?$',
  ).firstMatch(value);
  if (match == null) return null;

  int parseOrDefault(String? input, int fallback) =>
      input == null || input.isEmpty ? fallback : int.parse(input);

  final startYear = parseOrDefault(match.group(1), defaultYear);
  final startMonth = int.parse(match.group(2)!);
  final startDay = int.parse(match.group(3)!);
  final endYearRaw = match.group(4);
  final endMonth = int.parse(match.group(5)!);
  final endDay = int.parse(match.group(6)!);

  final start = DateTime(startYear, startMonth, startDay);
  var endYear = parseOrDefault(endYearRaw, startYear);
  var end = DateTime(endYear, endMonth, endDay);
  if (end.isBefore(start) && endYearRaw == null) {
    endYear = startYear + 1;
    end = DateTime(endYear, endMonth, endDay);
  }

  if (end.isBefore(start)) return null;
  return _TodoRange(start: _dateOnly(start), end: _dateOnly(end));
}

_Hol? _holidayForDate(DateTime date) => _chinaHolidays2026[_dateOnly(date)];

final Map<DateTime, _Hol> _chinaHolidays2026 = {
  for (final date in _dates(DateTime(2026, 1, 1), DateTime(2026, 1, 3)))
    date: _Hol(name: date.day == 1 ? '元旦' : null, rest: true),
  DateTime(2026, 1, 4): const _Hol(name: '调休', work: true),
  DateTime(2026, 2, 14): const _Hol(name: '调休', work: true),
  for (final date in _dates(DateTime(2026, 2, 15), DateTime(2026, 2, 23)))
    date: _Hol(name: date.day == 17 ? '春节' : null, rest: true),
  DateTime(2026, 2, 28): const _Hol(name: '调休', work: true),
  for (final date in _dates(DateTime(2026, 4, 4), DateTime(2026, 4, 6)))
    date: _Hol(name: date.day == 5 ? '清明节' : null, rest: true),
  for (final date in _dates(DateTime(2026, 5, 1), DateTime(2026, 5, 5)))
    date: _Hol(name: date.day == 1 ? '劳动节' : null, rest: true),
  DateTime(2026, 5, 9): const _Hol(name: '调休', work: true),
  for (final date in _dates(DateTime(2026, 6, 19), DateTime(2026, 6, 21)))
    date: _Hol(name: date.day == 19 ? '端午节' : null, rest: true),
  for (final date in _dates(DateTime(2026, 9, 25), DateTime(2026, 9, 27)))
    date: _Hol(name: date.day == 25 ? '中秋节' : null, rest: true),
  DateTime(2026, 9, 20): const _Hol(name: '调休', work: true),
  for (final date in _dates(DateTime(2026, 10, 1), DateTime(2026, 10, 7)))
    date: _Hol(name: date.day == 1 ? '国庆节' : null, rest: true),
  DateTime(2026, 10, 10): const _Hol(name: '调休', work: true),
};

List<DateTime> _dates(DateTime start, DateTime end) {
  final dates = <DateTime>[];
  var date = _dateOnly(start);
  final last = _dateOnly(end);
  while (!date.isAfter(last)) {
    dates.add(date);
    date = date.add(const Duration(days: 1));
  }
  return dates;
}

const _weekLabels = ['日', '一', '二', '三', '四', '五', '六'];
const _yearWeekLabels = ['日', '一', '二', '三', '四', '五', '六'];

// 年视图卡片统一字体样式（12px，三档颜色）
const _cardLabelStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);
const _cardValueStyle = TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500);
const _cardAccentStyle = TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w500);
const _collapsedMonthRowHeight = 76.0;
const _expandedMonthRowHeight = 100.0;
const _rangeBandHeightFactor = 0.45;
const _calendarHorizontalPadding = 18.0;
const _selectedDateColor = AppColors.periodLight;
const _todayDateColor = AppColors.period;

DateTime get _todayDate {
  final now = _beijingNow();
  return DateTime(now.year, now.month, now.day);
}

int get _today => _todayDate.day;

String _monthLabel(int month) {
  const labels = [
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ];
  return labels[month - 1];
}

// 顶部视图切换：月、周、日、年四种展示模式。
enum _View { month, week, day, year }

// 主界面。
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 页面状态集中在这里：当前视图和选中的日期。
  _View _view = _View.month;
  DateTime _displayedMonth = DateTime(_todayDate.year, _todayDate.month);
  int _selected = _today;
  Timer? _todayTimer;

  @override
  void initState() {
    super.initState();
    _scheduleTodayRefresh();
  }

  @override
  void dispose() {
    _todayTimer?.cancel();
    super.dispose();
  }

  void _scheduleTodayRefresh() {
    _todayTimer?.cancel();
    final now = _beijingNow();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _todayTimer =
        Timer(tomorrow.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTodayRefresh();
    });
  }

  void _setDisplayedMonth(int year, int month) {
    final maxDay = DateUtils.getDaysInMonth(year, month);
    setState(() {
      _displayedMonth = DateTime(year, month);
      _selected = _selected.clamp(1, maxDay).toInt();
    });
  }

  void _shiftDisplayedMonth(int delta) {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    _setDisplayedMonth(next.year, next.month);
  }

  void _setDisplayedYear(int year) {
    _setDisplayedMonth(year, _displayedMonth.month);
  }

  void _shiftDisplayedYear(int delta) {
    _setDisplayedYear(_displayedMonth.year + delta);
  }

  void _selectDate(DateTime date) {
    setState(() {
      _displayedMonth = DateTime(date.year, date.month);
      _selected = date.day;
    });
  }

  void _selectDayInDisplayedMonth(int day) {
    setState(() {
      _selected = day;
    });
  }

  void _openDayView(DateTime date) {
    setState(() {
      _displayedMonth = DateTime(date.year, date.month);
      _selected = date.day;
      _view = _View.day;
    });
  }

  void _openMonthView(int year, int month) {
    final maxDay = DateUtils.getDaysInMonth(year, month);
    setState(() {
      _displayedMonth = DateTime(year, month);
      _selected = _selected.clamp(1, maxDay).toInt();
      _view = _View.month;
    });
  }

  void _goTodayKeepingView() {
    final today = _todayDate;
    setState(() {
      _displayedMonth = DateTime(today.year, today.month);
      _selected = today.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ImportantDateStore.version,
        HealthStore.periodRecords,
        HealthStore.fitnessRecords,
        TodoStore.items,
        WeightStore.weights,
      ]),
      builder: (context, _) {
        return SafeArea(
          child: Column(
            children: [
              _Header(
                  view: _view,
                  displayDate: DateTime(
                      _displayedMonth.year, _displayedMonth.month, _selected),
                  onMonthTap: _view == _View.month
                      ? () => _showMonthPicker(context)
                      : _view == _View.year
                          ? () => _showYearPicker(context)
                          : null,
                  onTodayTap: _goTodayKeepingView,
                  onView: (v) => setState(() => _view = v)),
              Expanded(
                // 根据顶部选择切换不同视图；选中日期通过回调在父组件中保持同步。
                child: switch (_view) {
                  _View.month => _MonthView(
                      year: _displayedMonth.year,
                      month: _displayedMonth.month,
                      selected: _selected,
                      onSelect: _selectDayInDisplayedMonth,
                      onSelectDate: _selectDate,
                      onOpenDay: _openDayView,
                      onMonthChanged: _shiftDisplayedMonth,
                      onCollapseToWeek: () =>
                          setState(() => _view = _View.week),
                    ),
                  _View.week => _WeekView(
                      year: _displayedMonth.year,
                      month: _displayedMonth.month,
                      selected: _selected,
                      onSelectDate: _selectDate,
                      onOpenDay: _openDayView,
                      onExpandToMonth: () =>
                          setState(() => _view = _View.month),
                    ),
                  _View.day => _DayView(
                      year: _displayedMonth.year,
                      month: _displayedMonth.month,
                      selected: _selected,
                      onSelectDate: _selectDate,
                    ),
                  _View.year => _YearView(
                      year: _displayedMonth.year,
                      onYearSwiped: _shiftDisplayedYear,
                      onOpenMonth: (month) =>
                          _openMonthView(_displayedMonth.year, month),
                    ),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    var year = _displayedMonth.year;
    var month = _displayedMonth.month;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('选择年月',
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: year,
                      isExpanded: true,
                      items: List.generate(21, (i) => _todayDate.year - 10 + i)
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value年'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => year = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int>(
                      value: month,
                      isExpanded: true,
                      items: List.generate(12, (i) => i + 1)
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value月'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => month = value);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DateTime(year, month),
                  ),
                  child: const Text('确定',
                      style: TextStyle(
                          color: AppColors.brand, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) return;
    _setDisplayedMonth(picked.year, picked.month);
  }

  Future<void> _showYearPicker(BuildContext context) async {
    var year = _displayedMonth.year;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('选择年份',
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              content: DropdownButton<int>(
                value: year,
                isExpanded: true,
                items: List.generate(31, (i) => _todayDate.year - 15 + i)
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value年'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => year = value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, year),
                  child: const Text('确定',
                      style: TextStyle(
                          color: AppColors.brand, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) return;
    _setDisplayedYear(picked);
  }
}

// 头部栏。
class _Header extends StatelessWidget {
  final _View view;
  final DateTime displayDate;
  final VoidCallback? onMonthTap;
  final VoidCallback onTodayTap;
  final ValueChanged<_View> onView;
  const _Header(
      {required this.view,
      required this.displayDate,
      required this.onMonthTap,
      required this.onTodayTap,
      required this.onView});

  @override
  Widget build(BuildContext context) {
    final titleText = view == _View.year
        ? '${displayDate.year}年'
        : _monthLabel(displayDate.month);
    final showSubtitle = view != _View.year;
    final subtitleText = '${displayDate.year} · ${_lunarYearText(displayDate)}';

    // 日历标题区：左侧显示月份和农历年份，右侧负责视图切换与新增入口。
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onMonthTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titleText,
                        style: const TextStyle(
                          fontFamily: 'XinDiXiaWuCha',
                          fontSize: 22,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        )),
                    if (onMonthTap != null) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 16, color: AppColors.textSecondary),
                    ],
                  ],
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 5),
                  Text(subtitleText,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        color: AppColors.textSecondary,
                      )),
                ],
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTodayTap,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _todayDateColor.withAlpha(24),
                shape: BoxShape.circle,
                border: Border.all(color: _todayDateColor.withAlpha(120)),
              ),
              child: const Text(
                '今',
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  color: _todayDateColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _SegControl(
            options: const ['月', '周', '日', '年'],
            active: ['月', '周', '日', '年'][_View.values.indexOf(view)],
            onTap: (s) => onView(_View.values[['月', '周', '日', '年'].indexOf(s)]),
          ),
        ],
      ),
    );
  }
}

// 分段控制器。
class _SegControl extends StatelessWidget {
  final List<String> options;
  final String active;
  final ValueChanged<String> onTap;
  const _SegControl(
      {required this.options, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 轻量分段控件，用 AnimatedContainer 表现当前选中项的反馈。
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgTab,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final sel = o == active;
          return GestureDetector(
            onTap: () => onTap(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: sel
                    ? [
                        const BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 4,
                            offset: Offset(0, 1))
                      ]
                    : null,
              ),
              child: Text(o,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        sel ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w500 : FontWeight.normal,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 月视图。
class _MonthView extends StatefulWidget {
  final int year;
  final int month;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime> onOpenDay;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onCollapseToWeek;

  const _MonthView({
    required this.year,
    required this.month,
    required this.selected,
    required this.onSelect,
    required this.onSelectDate,
    required this.onOpenDay,
    required this.onMonthChanged,
    required this.onCollapseToWeek,
  });

  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> {
  _MonthCalendarMode _mode = _MonthCalendarMode.month;
  double _gridDragOffset = 0;
  double _gridSwipeOffset = 0;
  final ScrollController _detailScrollCtrl = ScrollController();
  Offset? _detailDragStart;
  double _detailDragStartOffset = 0;

  @override
  void dispose() {
    _detailScrollCtrl.dispose();
    super.dispose();
  }

  void _setMode(_MonthCalendarMode value) {
    if (_mode == value) return;
    setState(() => _mode = value);
  }

  void _handleVerticalCalendarDrag(double delta) {
    if (delta < 0) {
      if (_mode == _MonthCalendarMode.detail) {
        _setMode(_MonthCalendarMode.month);
      } else {
        widget.onCollapseToWeek();
      }
    } else if (delta > 0) {
      _setMode(_mode == _MonthCalendarMode.week
          ? _MonthCalendarMode.month
          : _MonthCalendarMode.detail);
    }
  }

  List<DateTime> _selectedWeekDates() {
    final selectedDate = DateTime(widget.year, widget.month, widget.selected);
    final start =
        selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  Widget _buildWeekCalendarStrip() {
    final dates = _selectedWeekDates();
    final today = _todayDate;
    final events = _eventsForMonth(widget.year, widget.month);
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: _calendarHorizontalPadding),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: List.generate(7, (i) {
            final date = dates[i];
            final inCurrentMonth =
                date.year == widget.year && date.month == widget.month;
            final isToday = DateUtils.isSameDay(date, today);
            final isSelected = inCurrentMonth && date.day == widget.selected;
            final ev = inCurrentMonth ? events[date.day] : null;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectDate(date),
                onDoubleTap: () => widget.onOpenDay(date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weekLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: i == 0 || i == 6
                              ? AppColors.holiday
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday
                              ? _todayDateColor
                              : isSelected
                                  ? _selectedDateColor
                                  : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isToday
                                  ? Colors.white
                                  : inCurrentMonth
                                      ? (i == 0 || i == 6
                                          ? AppColors.holiday
                                          : AppColors.textPrimary)
                                      : AppColors.textSecondary.withAlpha(130),
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ev?.period == true
                              ? AppColors.period
                              : ev?.birthday != null
                                  ? AppColors.birthday
                                  : ev?.eventName != null
                                      ? AppColors.event
                                      : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // 按固定行高构建日历行，避免 GridView 在不同屏幕宽度下出现高度溢出。
  Widget _buildCalendarGrid(
    List<_MonthDay> cells, {
    double? maxHeight,
  }) {
    final preferredRowHeight = switch (_mode) {
      _MonthCalendarMode.week => 62.0,
      _MonthCalendarMode.month => _collapsedMonthRowHeight,
      _MonthCalendarMode.detail => _expandedMonthRowHeight,
    };
    final today = _todayDate;
    final events = _eventsForMonth(widget.year, widget.month);
    final monthStartDay = DateTime(widget.year, widget.month, 1).weekday % 7;
    final rowCount = (cells.length / 7).ceil();
    final rowHeight = maxHeight == null
        ? preferredRowHeight
        : _mode == _MonthCalendarMode.detail
            ? preferredRowHeight
            : math.min(preferredRowHeight, maxHeight / rowCount);
    Widget buildRow(int rowIdx) {
      final start = rowIdx * 7;
      final end = (start + 7).clamp(0, cells.length);
      final rowCells = List<_MonthDay>.from(cells.sublist(start, end));
      while (rowCells.length < 7) {
        rowCells.add(const _MonthDay(day: 0, inCurrentMonth: false));
      }

      final periodRuns = <_PeriodRun>[];
      final eventRuns = <_PeriodRun>[];
      int? runStart;
      for (var i = 0; i < rowCells.length; i++) {
        final cell = rowCells[i];
        final inPeriod = cell.day != 0 &&
            cell.inCurrentMonth &&
            (events[cell.day]?.period ?? false);
        if (inPeriod) {
          runStart ??= i;
        } else if (runStart != null) {
          periodRuns.add(_PeriodRun(startIndex: runStart, endIndex: i - 1));
          runStart = null;
        }
      }
      if (runStart != null) {
        periodRuns.add(_PeriodRun(startIndex: runStart, endIndex: 6));
      }

      runStart = null;
      for (var i = 0; i < rowCells.length; i++) {
        final cell = rowCells[i];
        final inEvent = cell.day != 0 &&
            cell.inCurrentMonth &&
            (events[cell.day]?.eventBand ?? false);
        if (inEvent) {
          runStart ??= i;
        } else if (runStart != null) {
          eventRuns.add(_PeriodRun(startIndex: runStart, endIndex: i - 1));
          runStart = null;
        }
      }
      if (runStart != null) {
        eventRuns.add(_PeriodRun(startIndex: runStart, endIndex: 6));
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;
          final bandHeight = _mode == _MonthCalendarMode.detail
              ? 36.0
              : rowHeight * _rangeBandHeightFactor;
          final bandTop = _mode == _MonthCalendarMode.detail
              ? 13.0
              : (rowHeight - bandHeight) / 2;
          final bandUnitWidth = math.min(58.0, cellWidth);

          return Stack(
            children: [
              for (final run in eventRuns)
                Positioned(
                  left: ((run.startIndex + run.endIndex + 1) * cellWidth -
                          (run.endIndex - run.startIndex + 1) * bandUnitWidth) /
                      2,
                  top: bandTop,
                  width: (run.endIndex - run.startIndex + 1) * bandUnitWidth,
                  height: bandHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.event.withAlpha(22),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              for (final run in periodRuns)
                Positioned(
                  left: ((run.startIndex + run.endIndex + 1) * cellWidth -
                          (run.endIndex - run.startIndex + 1) * bandUnitWidth) /
                      2,
                  top: bandTop,
                  width: (run.endIndex - run.startIndex + 1) * bandUnitWidth,
                  height: bandHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.periodBg.withAlpha(82),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              Row(
                children: rowCells
                    .map((cell) => Expanded(
                          child: cell.day == 0
                              ? const SizedBox()
                              : _DayCell(
                                  year: widget.year,
                                  month: widget.month,
                                  day: cell.day,
                                  selected: cell.inCurrentMonth &&
                                      cell.day == widget.selected,
                                  today: cell.inCurrentMonth &&
                                      widget.year == today.year &&
                                      widget.month == today.month &&
                                      cell.day == today.day,
                                  ev: cell.inCurrentMonth
                                      ? events[cell.day]
                                      : null,
                                  hol: cell.inCurrentMonth
                                      ? _holidayForDate(DateTime(
                                          widget.year,
                                          widget.month,
                                          cell.day,
                                        ))
                                      : null,
                                  monthStartDay: monthStartDay,
                                  showLabels:
                                      _mode == _MonthCalendarMode.detail &&
                                          rowHeight >= 58,
                                  muted: !cell.inCurrentMonth,
                                  onTap: cell.inCurrentMonth
                                      ? () => widget.onSelect(cell.day)
                                      : null,
                                  onDoubleTap: cell.inCurrentMonth
                                      ? () => widget.onOpenDay(
                                            DateTime(
                                              widget.year,
                                              widget.month,
                                              cell.day,
                                            ),
                                          )
                                      : null,
                                ),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      );
    }

    return Column(
      children: List.generate(rowCount, (rowIdx) {
        return SizedBox(
          height: rowHeight,
          child: buildRow(rowIdx),
        );
      }),
    );
  }

  Widget _buildScrollableDetailCalendarGrid(List<_MonthDay> cells) {
    final rowCount = (cells.length / 7).ceil();
    return Listener(
      onPointerDown: (event) {
        _detailDragStart = event.localPosition;
        _detailDragStartOffset =
            _detailScrollCtrl.hasClients ? _detailScrollCtrl.offset : 0.0;
      },
      onPointerMove: (event) {
        final start = _detailDragStart;
        if (start == null) return;
        final dy = event.localPosition.dy - start.dy;
        if (_detailDragStartOffset <= 1 && dy < -50) {
          _detailDragStart = null;
          _setMode(_MonthCalendarMode.month);
        }
      },
      onPointerUp: (_) => _detailDragStart = null,
      onPointerCancel: (_) => _detailDragStart = null,
      child: SingleChildScrollView(
        controller: _detailScrollCtrl,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: _expandedMonthRowHeight * rowCount,
          child: _buildCalendarGrid(cells),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previousMonthDays = DateTime(widget.year, widget.month, 0).day;
    final monthStartDay = DateTime(widget.year, widget.month, 1).weekday % 7;
    final daysCount = DateUtils.getDaysInMonth(widget.year, widget.month);
    final cells = <_MonthDay>[
      ...List.generate(
        monthStartDay,
        (i) => _MonthDay(
          day: previousMonthDays - monthStartDay + i + 1,
          inCurrentMonth: false,
        ),
      ),
      ...List.generate(
        daysCount,
        (i) => _MonthDay(day: i + 1, inCurrentMonth: true),
      ),
    ];
    while (cells.length < 42) {
      cells.add(_MonthDay(
        day: cells.length - monthStartDay - daysCount + 1,
        inCurrentMonth: false,
      ));
    }

    return Column(
      children: [
        // 星期标题行。
        if (_mode != _MonthCalendarMode.week) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: _calendarHorizontalPadding),
            child: Row(
              children: _weekLabels
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                fontSize: 11,
                                color: d == '日' || d == '六'
                                    ? AppColors.holiday
                                    : AppColors.textSecondary,
                              )),
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (_mode == _MonthCalendarMode.month) const SizedBox(height: 2),
        ],
        Expanded(
          flex: _mode == _MonthCalendarMode.month ? 9 : 1,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _handleVerticalCalendarDrag(event.scrollDelta.dy);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _gridDragOffset = 0,
              onVerticalDragUpdate: (details) {
                _gridDragOffset += details.primaryDelta ?? 0;
              },
              onVerticalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                final disp = _gridDragOffset;
                _gridDragOffset = 0;
                if (v < -400 || (v < -100 && disp < -50)) {
                  _handleVerticalCalendarDrag(-1);
                } else if (v > 400 || (v > 100 && disp > 50)) {
                  _handleVerticalCalendarDrag(1);
                }
              },
              onHorizontalDragStart: (_) => _gridSwipeOffset = 0,
              onHorizontalDragUpdate: (details) {
                _gridSwipeOffset += details.primaryDelta ?? 0;
                if (_gridSwipeOffset < -42) {
                  _gridSwipeOffset = 0;
                  widget.onMonthChanged(1);
                } else if (_gridSwipeOffset > 42) {
                  _gridSwipeOffset = 0;
                  widget.onMonthChanged(-1);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: _calendarHorizontalPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      child: _mode == _MonthCalendarMode.week
                          ? _buildWeekCalendarStrip()
                          : _mode == _MonthCalendarMode.detail
                              ? _buildScrollableDetailCalendarGrid(cells)
                              : _buildCalendarGrid(
                                  cells,
                                  maxHeight: constraints.maxHeight,
                                ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (_mode != _MonthCalendarMode.detail)
          Expanded(
            flex: _mode == _MonthCalendarMode.month ? 2 : 1,
            child: _CalendarInfoPanels(
              selectedDate:
                  DateTime(widget.year, widget.month, widget.selected),
            ),
          ),
      ],
    );
  }
}

enum _MonthCalendarMode { month, week, detail }

class _MonthDay {
  final int day;
  final bool inCurrentMonth;
  const _MonthDay({required this.day, required this.inCurrentMonth});
}

class _PeriodRun {
  final int startIndex;
  final int endIndex;
  const _PeriodRun({required this.startIndex, required this.endIndex});
}

// 日期单元格。
class _DayLabel {
  final String text;
  final Color color;
  const _DayLabel(this.text, this.color);
}

class _DayCell extends StatelessWidget {
  final int year;
  final int month;
  final int day;
  final bool selected;
  final bool today;
  final _Ev? ev;
  final _Hol? hol;
  final int monthStartDay;
  final bool showLabels;
  final bool muted;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const _DayCell({
    required this.year,
    required this.month,
    required this.day,
    required this.selected,
    required this.today,
    required this.ev,
    required this.hol,
    required this.monthStartDay,
    this.showLabels = false,
    this.muted = false,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    // 单个日期格会根据今天、选中状态、节假日、生理期和事件组合决定颜色与角标。
    final isPeriodStart = ev?.periodStart == true;
    final isPeriodEnd = ev?.periodEnd == true;
    final colIndex = (day + monthStartDay - 1) % 7;
    final isWeekend = colIndex == 0 || colIndex == 6;
    final lunarStr = _lunarDay(DateTime(year, month, day));
    final labels = _labels.take(3).toList();
    final dateColor = today
        ? Colors.white
        : muted
            ? AppColors.textSecondary.withAlpha(130)
            : ((isWeekend && hol?.work != true) || hol?.rest == true)
                ? AppColors.holiday
                : AppColors.textPrimary;
    final lunarColor = today
        ? Colors.white70
        : muted
            ? AppColors.textSecondary.withAlpha(120)
            : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isPeriodStart ? const Radius.circular(12) : Radius.zero,
            right: isPeriodEnd ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment:
                  showLabels ? const Alignment(0, -0.6) : Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: today
                          ? _todayDateColor
                          : selected
                              ? _selectedDateColor
                              : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1,
                              color: dateColor,
                              fontWeight: today || selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                        const SizedBox(height: 2),
                        Text(lunarStr,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              color: lunarColor,
                            )),
                      ],
                    ),
                  ),
                  if (hol?.rest == true || hol?.work == true)
                    Positioned(
                      top: -2,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEA),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(hol?.work == true ? '班' : '休',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.holiday,
                                height: 1.5)),
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: showLabels
                  ? const Alignment(0, 0.88)
                  : const Alignment(0, 0.86),
              child: showLabels && labels.isNotEmpty
                  ? SizedBox(
                      height: 52,
                      child: ClipRect(
                        child: Transform.translate(
                          offset: const Offset(0, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final label in labels)
                                Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 62),
                                  margin: const EdgeInsets.only(bottom: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 0),
                                  decoration: BoxDecoration(
                                    color: label.color.withAlpha(30),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    label.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.1,
                                      color: label.color,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ev?.birthday != null)
                          _Dot(color: AppColors.birthday),
                        if (ev?.eventName != null) _Dot(color: AppColors.event),
                        if (ev?.period == true) _Dot(color: AppColors.period),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DayLabel> get _labels {
    final labels = <_DayLabel>[];
    if (hol?.name != null) {
      labels.add(_DayLabel(hol!.name!, AppColors.holiday));
    }
    if (ev?.birthday != null) {
      labels.add(_DayLabel(ev!.birthday!, AppColors.birthday));
    }
    final eventNames = ev?.eventName
        ?.split(RegExp(r'\s*(?:·|路)\s*'))
        .where((value) => value.trim().isNotEmpty);
    if (eventNames != null) {
      for (final name in eventNames) {
        labels.add(_DayLabel(name.trim(), AppColors.event));
      }
    }
    if (ev?.todo == true) {
      labels.add(const _DayLabel('待办', AppColors.brand));
    }
    if (ev?.period == true) {
      labels.add(const _DayLabel('生理期', AppColors.period));
    }
    return labels;
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _TodoPlanRow extends StatelessWidget {
  final int index;
  final TodoItem todo;
  final ValueChanged<TodoItem>? onEdit;
  final ValueChanged<TodoItem>? onDelete;
  const _TodoPlanRow({
    required this.index,
    required this.todo,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete?.call(todo);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            const Icon(Icons.delete_outline, size: 18, color: AppColors.brand),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onEdit?.call(todo);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.brandLight.withAlpha(78),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text('$index',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(todo.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w400,
                    )),
              ),
              const Icon(Icons.chevron_right,
                  size: 15, color: AppColors.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarInfoPanels extends StatelessWidget {
  final DateTime selectedDate;

  const _CalendarInfoPanels({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          children: [
            _TodoInfoCard(
              onAdd: () => _showAddTodoDialog(context),
              onEdit: (todo) => _showTodoDialog(context, todo: todo),
              onDelete: (todo) => TodoStore.remove(todo.id),
            ),
            const SizedBox(height: 12),
            _UpcomingInfoCard(
              selectedDate: selectedDate,
              onAdd: () => _showImportantDateDialog(context, selectedDate),
              onEdit: (item) => _showImportantDateDialog(
                context,
                selectedDate,
                item: item,
              ),
              onDelete: (item) => _confirmRemoveImportantDate(context, item),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTodoDialog(BuildContext context) async {
    await _showTodoDialog(context);
  }

  Future<void> _showTodoDialog(BuildContext context, {TodoItem? todo}) async {
    final editing = todo != null;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TodoInputDialog(
        initialText: todo?.text,
        editing: editing,
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      if (editing) {
        TodoStore.update(todo.id, result);
      } else {
        TodoStore.add(result);
      }
    }
  }

  Future<void> _showImportantDateDialog(
      BuildContext context, DateTime selectedDate,
      {UpcomingImportantDate? item}) async {
    const top = 56.0;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    top,
                    16,
                    MediaQuery.of(dialogContext).viewInsets.bottom + 20,
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 360,
                        maxHeight: MediaQuery.of(dialogContext).size.height
                            - top
                            - MediaQuery.of(dialogContext).viewInsets.bottom
                            - 40,
                      ),
                      child: _ImportantDateDialog(
                        initialDate: selectedDate,
                        item: item,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmRemoveImportantDate(
    BuildContext context,
    UpcomingImportantDate item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('删除近期时间',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              )),
          content: Text('确定删除”${item.title}”吗？记录页中的对应信息也会同步移除。',
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除',
                  style: TextStyle(
                      color: AppColors.holiday, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      ImportantDateStore.removeUpcoming(item.type, item.id);
      return true;
    }
    return false;
  }
}

class _TodoInputDialog extends StatefulWidget {
  final String? initialText;
  final bool editing;
  const _TodoInputDialog({this.initialText, required this.editing});

  @override
  State<_TodoInputDialog> createState() => _TodoInputDialogState();
}

class _TodoInputDialogState extends State<_TodoInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.fromLTRB(
        40,
        24,
        40,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      title: Text(
        widget.editing ? '修改待办事项' : '添加待办事项',
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: '待办内容，例如：5月1日-5月3日 出差',
          hintStyle:
              const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.bgPage,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.brand),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.editing ? '保存' : '添加',
            style: const TextStyle(
              color: AppColors.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoInfoCard extends StatelessWidget {
  final VoidCallback onAdd;
  final ValueChanged<TodoItem> onEdit;
  final ValueChanged<TodoItem> onDelete;
  const _TodoInfoCard({
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      title: '待办事项',
      action: GestureDetector(
        onTap: onAdd,
        child: const Icon(Icons.add_circle_outline,
            size: 18, color: AppColors.brand),
      ),
      child: ValueListenableBuilder<List<TodoItem>>(
        valueListenable: TodoStore.items,
        builder: (context, todos, _) {
          if (todos.isEmpty) {
            return const Text('暂无待办',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todos.length,
            itemBuilder: (_, i) => _TodoPlanRow(
              index: i + 1,
              todo: todos[i],
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          );
        },
      ),
    );
  }
}

class _UpcomingInfoCard extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onAdd;
  final ValueChanged<UpcomingImportantDate> onEdit;
  final Future<bool?> Function(UpcomingImportantDate) onDelete;
  const _UpcomingInfoCard({
    required this.selectedDate,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      title: '近期时间',
      action: GestureDetector(
        onTap: onAdd,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.brand),
            Text('添加', style: TextStyle(fontSize: 11, color: AppColors.brand)),
          ],
        ),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: ImportantDateStore.version,
        builder: (context, _, __) {
          final items = ImportantDateStore.upcomingWithinMonths(
            today: dateOnly(selectedDate),
            months: 2,
          );
          if (items.isEmpty) {
            return const Text('暂无重要时间',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, i) => _UpcomingImportantRow(
              item: items[i],
              selectedDate: selectedDate,
              last: i == items.length - 1,
              onEdit: () => onEdit(items[i]),
              onDelete: () => onDelete(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _UpcomingImportantRow extends StatelessWidget {
  final UpcomingImportantDate item;
  final DateTime selectedDate;
  final bool last;
  final VoidCallback onEdit;
  final Future<bool?> Function() onDelete;
  const _UpcomingImportantRow({
    required this.item,
    required this.selectedDate,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  IconData get _icon {
    switch (item.type) {
      case ImportantDateType.event:
        return Icons.flag_outlined;
      case ImportantDateType.birthday:
        return Icons.cake_outlined;
      case ImportantDateType.anniversary:
        return Icons.auto_awesome_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = item.date.difference(dateOnly(selectedDate)).inDays;
    final dayText = days == 0
        ? '今天'
        : days == 1
            ? '明天'
            : days > 1
                ? '$days 天后'
                : '已过 ${-days} 天';
    return Dismissible(
      key: ValueKey('${item.type.name}_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await onDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: item.color.withValues(alpha: 0.10),
        child: Icon(Icons.delete_outline, size: 20, color: item.color),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onEdit();
        },
        child: Container(
          padding: EdgeInsets.only(bottom: last ? 0 : 10, top: last ? 0 : 0),
          margin: EdgeInsets.only(bottom: last ? 0 : 10),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w400)),
                    const SizedBox(height: 3),
                    Text('${item.dateText} · ${item.subtitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(dayText, style: TextStyle(fontSize: 13, color: item.color)),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportantDateDialog extends StatefulWidget {
  final DateTime initialDate;
  final UpcomingImportantDate? item;

  const _ImportantDateDialog({
    required this.initialDate,
    this.item,
  });

  @override
  State<_ImportantDateDialog> createState() => _ImportantDateDialogState();
}

class _ImportantDateDialogState extends State<_ImportantDateDialog> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  ImportantDateType _type = ImportantDateType.event;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _eventSpansDays = false;
  String? _error;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _startDate = dateOnly(widget.initialDate);
    _endDate = _startDate;
    _loadEditingItem();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (_type) {
      case ImportantDateType.event:
        return const Color(0xFFD76F72);
      case ImportantDateType.birthday:
        return AppColors.birthday;
      case ImportantDateType.anniversary:
        return const Color(0xFF8B6BAE);
    }
  }

  void _loadEditingItem() {
    final item = widget.item;
    if (item == null) return;
    _type = item.type;
    switch (item.type) {
      case ImportantDateType.event:
        for (final event in ImportantDateStore.events) {
          if (event.id != item.id) continue;
          _titleCtrl.text = event.title;
          _noteCtrl.text = event.note;
          _startDate = event.startDate;
          _endDate = event.endDate;
          _eventSpansDays =
              !DateUtils.isSameDay(event.startDate, event.endDate);
          return;
        }
        break;
      case ImportantDateType.birthday:
        for (final birthday in ImportantDateStore.birthdays) {
          if (birthday.id != item.id) continue;
          _titleCtrl.text = birthday.name;
          _startDate = DateTime(
              birthday.solarYear, birthday.solarMonth, birthday.solarDay);
          _endDate = _startDate;
          return;
        }
        break;
      case ImportantDateType.anniversary:
        for (final anniversary in ImportantDateStore.anniversaries) {
          if (anniversary.id != item.id) continue;
          _titleCtrl.text = anniversary.name;
          _startDate = DateTime(
            anniversary.solarYear,
            anniversary.solarMonth,
            anniversary.solarDay,
          );
          _endDate = _startDate;
          return;
        }
        break;
    }
    _titleCtrl.text = item.title;
    _startDate = item.date;
    _endDate = item.date;
  }

  String get _titleHint {
    switch (_type) {
      case ImportantDateType.event:
        return '重要事件名称';
      case ImportantDateType.birthday:
        return '姓名';
      case ImportantDateType.anniversary:
        return '纪念日名称';
    }
  }

  String _typeText(ImportantDateType type) {
    switch (type) {
      case ImportantDateType.event:
        return '重要事件';
      case ImportantDateType.birthday:
        return '生日';
      case ImportantDateType.anniversary:
        return '纪念日';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
    bool allowFuture = true,
  }) async {
    final firstDate = DateTime(1930);
    final lastDate = allowFuture ? DateTime(2035, 12, 31) : _todayDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _color,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(dateOnly(picked));
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请输入名称');
      return;
    }

    switch (_type) {
      case ImportantDateType.event:
        ImportantDateStore.saveEvent(
          id: widget.item?.type == ImportantDateType.event
              ? widget.item?.id
              : null,
          title: title,
          startDate: _startDate,
          endDate: _eventSpansDays ? _endDate : _startDate,
          note: _noteCtrl.text.trim(),
        );
        break;
      case ImportantDateType.birthday:
        ImportantDateStore.saveBirthday(
          id: widget.item?.type == ImportantDateType.birthday
              ? widget.item?.id
              : null,
          name: title,
          solar: _startDate,
        );
        break;
      case ImportantDateType.anniversary:
        ImportantDateStore.saveAnniversary(
          id: widget.item?.type == ImportantDateType.anniversary
              ? widget.item?.id
              : null,
          name: title,
          solar: _startDate,
        );
        break;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEvent = _type == ImportantDateType.event;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_editing ? '修改近期时间' : '添加近期时间',
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: ImportantDateType.values.map((type) {
                    final selected = type == _type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: _editing
                            ? null
                            : () => setState(() {
                                  _type = type;
                                  _error = null;
                                  if (_type != ImportantDateType.event) {
                                    _eventSpansDays = false;
                                    _endDate = _startDate;
                                  }
                                }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? _color.withAlpha(28)
                                : AppColors.bgPage,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selected ? _color : AppColors.border),
                          ),
                          child: Text(_typeText(type),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: selected
                                      ? _color
                                      : AppColors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _ImportantDateTextField(
                  controller: _titleCtrl,
                  hint: _titleHint,
                  color: _color,
                ),
                const SizedBox(height: 10),
                _ImportantDatePickerField(
                  label: isEvent ? '事件日期' : '日期',
                  text: _formatDate(_startDate),
                  color: _color,
                  onTap: () => _pickDate(
                    initial: _startDate,
                    allowFuture: true,
                    onPicked: (date) => setState(() {
                      _startDate = date;
                      if (!_eventSpansDays || _endDate.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                    }),
                  ),
                ),
                if (isEvent) ...[
                  const SizedBox(height: 10),
                  _EventSpanSelector(
                    spansDays: _eventSpansDays,
                    color: _color,
                    onChanged: (value) => setState(() {
                      _eventSpansDays = value;
                      if (!_eventSpansDays || _endDate.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                    }),
                  ),
                  if (_eventSpansDays) ...[
                    const SizedBox(height: 10),
                    _ImportantDatePickerField(
                      label: '结束日期',
                      text: _formatDate(_endDate),
                      color: _color,
                      onTap: () => _pickDate(
                        initial: _endDate,
                        onPicked: (date) => setState(() {
                          _endDate =
                              date.isBefore(_startDate) ? _startDate : date;
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _ImportantDateTextField(
                    controller: _noteCtrl,
                    hint: '备注（可选）',
                    color: _color,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.holiday)),
                ],
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_editing ? '保存' : '添加'),
                ),
              ],
            ),
          ),
    );
  }
}

class _ImportantDateTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color color;
  const _ImportantDateTextField({
    required this.controller,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bgPage,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color)),
      ),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
    );
  }
}

class _ImportantDatePickerField extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final VoidCallback onTap;
  const _ImportantDatePickerField({
    required this.label,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            Text(text,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _EventSpanSelector extends StatelessWidget {
  final bool spansDays;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _EventSpanSelector({
    required this.spansDays,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(String text, bool value) {
      final selected = spansDays == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? color.withAlpha(28) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: selected ? color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          option('单日', false),
          option('连续多日', true),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _InfoPanel({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// 周视图。
class _WeekView extends StatelessWidget {
  final int year;
  final int month;
  final int selected;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime> onOpenDay;
  final VoidCallback onExpandToMonth;
  const _WeekView({
    required this.year,
    required this.month,
    required this.selected,
    required this.onSelectDate,
    required this.onOpenDay,
    required this.onExpandToMonth,
  });

  List<DateTime> _weekDates() {
    final selectedDate = DateTime(year, month, selected);
    final start =
        selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final dates = _weekDates();
    final today = _todayDate;
    final events = _eventsForMonth(year, month);
    return Column(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && event.scrollDelta.dy < 0) {
              onExpandToMonth();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 400) {
                onExpandToMonth();
              }
            },
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: List.generate(7, (i) {
                  final date = dates[i];
                  final inCurrentMonth =
                      date.year == year && date.month == month;
                  final ev = inCurrentMonth ? events[date.day] : null;
                  final isToday = DateUtils.isSameDay(date, today);
                  final isSelected = inCurrentMonth && date.day == selected;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelectDate(date),
                      onDoubleTap: () => onOpenDay(date),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _weekLabels[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: i == 0 || i == 6
                                    ? AppColors.holiday
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isToday
                                    ? _todayDateColor
                                    : isSelected
                                        ? _selectedDateColor
                                        : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isToday
                                        ? Colors.white
                                        : inCurrentMonth
                                            ? (i == 0 || i == 6
                                                ? AppColors.holiday
                                                : AppColors.textPrimary)
                                            : AppColors.textSecondary
                                                .withAlpha(130),
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ev?.period == true
                                    ? AppColors.period
                                    : ev?.birthday != null
                                        ? AppColors.birthday
                                        : ev?.eventName != null
                                            ? AppColors.event
                                            : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        Expanded(
          child: _CalendarInfoPanels(
            selectedDate: DateTime(year, month, selected),
          ),
        ),
      ],
    );
  }
}

String _lunarDateText(DateTime date) {
  final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();
  return '农历${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
}

class _DayView extends StatefulWidget {
  final int year;
  final int month;
  final int selected;
  final ValueChanged<DateTime> onSelectDate;
  const _DayView({
    required this.year,
    required this.month,
    required this.selected,
    required this.onSelectDate,
  });

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.year, widget.month, widget.selected);
  }

  @override
  void didUpdateWidget(covariant _DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year == widget.year &&
        oldWidget.month == widget.month &&
        oldWidget.selected == widget.selected) {
      return;
    }
    _date = DateTime(widget.year, widget.month, widget.selected);
  }

  void _navigate(DateTime newDate) {
    widget.onSelectDate(newDate);
    setState(() => _date = newDate);
  }

  @override
  Widget build(BuildContext context) {
    final lunarStr = _lunarDateText(_date);
    final dayOfWeek = _date.weekday % 7;
    const weekNames = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DayNavButton(
                  icon: Icons.chevron_left,
                  enabled: true,
                  onPressed: () =>
                      _navigate(_date.subtract(const Duration(days: 1))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${_date.day}',
                          style: const TextStyle(
                            fontSize: 50,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.holiday,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          color: AppColors.border,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekNames[dayOfWeek],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lunarStr,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _DayNavButton(
                  icon: Icons.chevron_right,
                  enabled: true,
                  onPressed: () =>
                      _navigate(_date.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _CalendarInfoPanels(
            selectedDate: _date,
          ),
        ),
      ],
    );
  }
}

class _DayNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _DayNavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      iconSize: 22,
      color: AppColors.brand,
      disabledColor: AppColors.textSecondary.withAlpha(90),
      style: IconButton.styleFrom(
        backgroundColor:
            enabled ? AppColors.brandLight.withAlpha(96) : AppColors.bgTab,
        minimumSize: const Size(38, 38),
        fixedSize: const Size(38, 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// 年视图。
class _YearView extends StatelessWidget {
  final int year;
  final ValueChanged<int> onYearSwiped;
  final ValueChanged<int> onOpenMonth;

  const _YearView({
    required this.year,
    required this.onYearSwiped,
    required this.onOpenMonth,
  });

  @override
  Widget build(BuildContext context) {
    // 年视图是概览页：上方显示统计卡片，下方用迷你月历展示全年事件分布。
    final today = _todayDate;
    final months = [
      for (var month = 1; month <= 12; month++)
        _MiniMonthData(
          '$month月',
          DateUtils.getDaysInMonth(year, month),
          DateTime(year, month, 1).weekday % 7,
          _yearMonthEvents(year, month),
        ),
    ];

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dx.abs() > 16) {
          onYearSwiped(event.scrollDelta.dx > 0 ? 1 : -1);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 240) return;
          onYearSwiped(velocity < 0 ? 1 : -1);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('年日历',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final veryNarrow = constraints.maxWidth < 330;
                return GridView.builder(
                  itemCount: months.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: veryNarrow ? 2 : 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    mainAxisExtent: veryNarrow ? 136 : 130,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final month = months[index];
                    return _MiniMonth(
                      data: month,
                      isCurrent: year == today.year && index == today.month - 1,
                      onTap: () => onOpenMonth(index + 1),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('年度记录',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
            _SyncedYearStatsPanel(year: year),
          ],
        ),
      ),
    );
  }
}

List<_ME> _yearMonthEvents(int year, int month) {
  final events = <int, Set<_YearEventType>>{};

  void add(DateTime date, _YearEventType type) {
    if (date.year != year || date.month != month) return;
    events.putIfAbsent(date.day, () => <_YearEventType>{}).add(type);
  }

  for (final event in ImportantDateStore.events) {
    var day = _dateOnly(event.startDate);
    while (!day.isAfter(event.endDate)) {
      add(day, _YearEventType.event);
      day = day.add(const Duration(days: 1));
    }
  }

  for (final birthday in ImportantDateStore.birthdays) {
    add(DateTime(year, birthday.solarMonth, birthday.solarDay),
        _YearEventType.birthday);
  }

  for (final anniversary in ImportantDateStore.anniversaries) {
    add(DateTime(year, anniversary.solarMonth, anniversary.solarDay),
        _YearEventType.anniversary);
  }

  for (var day = 1; day <= DateUtils.getDaysInMonth(year, month); day++) {
    final date = DateTime(year, month, day);
    final holiday = _holidayForDate(date);
    if (holiday?.rest == true) {
      add(date, _YearEventType.holiday);
    } else if (holiday?.work == true) {
      add(date, _YearEventType.workDay);
    }
    if (HealthStore.isPeriodDay(date)) {
      add(date, _YearEventType.period);
    }
  }

  return [
    for (final entry in events.entries) _ME(entry.key, entry.value),
  ];
}

bool _hasYearEvent(
  Map<int, Set<_YearEventType>> evMap,
  int? day,
  _YearEventType type,
) =>
    day != null && (evMap[day]?.contains(type) ?? false);

enum _YearEventType { birthday, anniversary, event, holiday, period, workDay }

class _ME {
  final int day;
  final Set<_YearEventType> types;
  const _ME(this.day, this.types);
}

class _MiniMonthData {
  final String name;
  final int days;
  final int start;
  final List<_ME> events;
  const _MiniMonthData(this.name, this.days, this.start, this.events);
}

class _MiniMonth extends StatelessWidget {
  final _MiniMonthData data;
  final bool isCurrent;
  final VoidCallback onTap;

  const _MiniMonth({
    required this.data,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 年视图中的迷你月历采用卡片式排版，优先保证全年浏览时的可读性。
    final evMap = {for (final e in data.events) e.day: e.types};
    final cells = <int?>[
      ...List.filled(data.start, null),
      ...List.generate(data.days, (i) => i + 1)
    ];
    while (cells.length < 42) {
      cells.add(null);
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                    child: Column(
                      children: [
                        Text(data.name,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(7, (index) {
                            final weekend = index == 0 || index == 6;
                            return Expanded(
                              child: Center(
                                child: Text(
                                  _yearWeekLabels[index],
                                  style: TextStyle(
                                    fontSize: 7,
                                    height: 1,
                                    color: weekend
                                        ? AppColors.holiday.withAlpha(160)
                                        : AppColors.textSecondary.withAlpha(140),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cellHeight = constraints.maxHeight / 6;
                              final stackHeight = math.min(26.0, cellHeight);
                              final numberSize =
                                  math.max(17.0, stackHeight - 5);
                              final numberFontSize =
                                  stackHeight < 24 ? 9.0 : 11.0;

                              return Column(
                                children: List.generate(6, (rowIndex) {
                                  final row =
                                      cells.skip(rowIndex * 7).take(7).toList();
                                  return Expanded(
                                    child: Row(
                                      children: List.generate(7, (columnIndex) {
                                        final d = row[columnIndex];
                                        if (d == null) {
                                          return const Expanded(
                                              child: SizedBox());
                                        }
                                        final types = evMap[d] ??
                                            const <_YearEventType>{};
                                        final leftDay = columnIndex == 0
                                            ? null
                                            : row[columnIndex - 1];
                                        final rightDay = columnIndex == 6
                                            ? null
                                            : row[columnIndex + 1];
                                        final periodSelected = types
                                            .contains(_YearEventType.period);
                                        final periodLeft = periodSelected &&
                                            _hasYearEvent(evMap, leftDay,
                                                _YearEventType.period);
                                        final periodRight = periodSelected &&
                                            _hasYearEvent(evMap, rightDay,
                                                _YearEventType.period);
                                        final isToday =
                                            isCurrent && d == _today;
                                        final isWeekend = columnIndex == 0 ||
                                            columnIndex == 6;
                                        final isWorkDay = types.contains(
                                            _YearEventType.workDay);
                                        final isHoliday = types.contains(
                                            _YearEventType.holiday);
                                        final isEvent =
                                            types.contains(_YearEventType.event) ||
                                            types.contains(_YearEventType.birthday) ||
                                            types.contains(_YearEventType.anniversary);
                                        final textColor = isToday
                                            ? Colors.white
                                            : isEvent
                                                ? AppColors.birthday
                                                : (isHoliday ||
                                                        (isWeekend &&
                                                            !isWorkDay))
                                                    ? AppColors.holiday
                                                    : AppColors.textPrimary;
                                        return Expanded(
                                          child: Center(
                                            child: SizedBox(
                                              height: stackHeight,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.center,
                                                children: [
                                                  if (periodSelected)
                                                    _YearRangeBand(
                                                      color: const Color(0xFFF5C8D8),
                                                      extendLeft: periodLeft,
                                                      extendRight: periodRight,
                                                    ),
                                                  Align(
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: Container(
                                                      width: 23,
                                                      height: numberSize,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isToday
                                                            ? AppColors.brand
                                                            : Colors
                                                                .transparent,
                                                        boxShadow: isToday
                                                            ? [
                                                                BoxShadow(
                                                                  color: AppColors
                                                                      .brand
                                                                      .withAlpha(
                                                                          70),
                                                                  blurRadius: 6,
                                                                  spreadRadius:
                                                                      0,
                                                                )
                                                              ]
                                                            : null,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '$d',
                                                          style: TextStyle(
                                                            fontSize:
                                                                numberFontSize,
                                                            height: 1,
                                                            color: textColor,
                                                            fontWeight: isToday
                                                                ? FontWeight.w600
                                                                : FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}


class _YearRangeBand extends StatelessWidget {
  final Color color;
  final bool extendLeft;
  final bool extendRight;

  const _YearRangeBand({
    required this.color,
    required this.extendLeft,
    required this.extendRight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 1,
          child: Container(
            height: 18,
            decoration: BoxDecoration(color: color),
          ),
        ),
      ),
    );
  }
}

class _SyncedYearStatsPanel extends StatelessWidget {
  final int year;
  const _SyncedYearStatsPanel({required this.year});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        WeightStore.weights,
        HealthStore.fitnessRecords,
      ]),
      builder: (context, _) {
        return Column(
          children: [
            _FitnessYearCard(year: year),
            const SizedBox(height: 10),
            _WeightYearCard(year: year),
          ],
        );
      },
    );
  }
}

// ── 健身年度卡 ──────────────────────────────────────────
class _FitnessYearCard extends StatelessWidget {
  final int year;
  const _FitnessYearCard({required this.year});

  @override
  Widget build(BuildContext context) {
    final byMonth = List.generate(
        12, (i) => HealthStore.fitnessLogForMonth(year, i + 1).length);
    final total = byMonth.fold(0, (s, n) => s + n);
    const goal = 150;
    final pct = (total / goal * 100).round();
    final maxVal = byMonth.isEmpty ? 0 : byMonth.reduce(math.max);
    final maxMonthIdx = maxVal > 0 ? byMonth.indexOf(maxVal) : -1;
    final nonZero = byMonth.where((v) => v > 0).toList();
    final avg = nonZero.isEmpty
        ? 0
        : (nonZero.fold(0, (s, n) => s + n) / nonZero.length).round();

    return _YearCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行 ──
          Row(
            children: [
              const Text('健身打卡', style: _cardLabelStyle),
              const SizedBox(width: 6),
              Text('$total 天', style: _cardValueStyle),
              const SizedBox(width: 4),
              const Text('/ $goal', style: _cardLabelStyle),
              const Spacer(),
              const Text('达成率  ', style: _cardLabelStyle),
              Text('$pct%', style: _cardAccentStyle),
            ],
          ),
          const SizedBox(height: 12),
          // ── 柱状图 ──
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final v = byMonth[i];
                final h = v == 0 ? 2.0 : math.max(2.0, (v / math.max(maxVal, 1)) * 34);
                final isMax = i == maxMonthIdx && v > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: v == 0
                            ? AppColors.border
                            : AppColors.brand.withAlpha(isMax ? 255 : 100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          const _MonthLabels(),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 10),
          // ── 统计行 ──
          Row(
            children: [
              const Text('最佳月  ', style: _cardLabelStyle),
              Text(maxMonthIdx >= 0 ? '${maxMonthIdx + 1}月' : '--',
                  style: _cardValueStyle),
              const Text('   ·   ', style: _cardLabelStyle),
              const Text('月均  ', style: _cardLabelStyle),
              Text(avg > 0 ? '$avg 天' : '--', style: _cardValueStyle),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 体重年度卡 ──────────────────────────────────────────
class _WeightYearCard extends StatelessWidget {
  final int year;
  const _WeightYearCard({required this.year});

  List<double?> _monthlyAvgWeights() {
    final wMap = WeightStore.weights.value;
    return List.generate(12, (i) {
      final month = i + 1;
      final vals = wMap.entries
          .where((e) {
            final d = WeightStore.dateFromKey(e.key);
            return d.year == year && d.month == month;
          })
          .map((e) => e.value)
          .toList();
      if (vals.isEmpty) return null;
      return vals.reduce((a, b) => a + b) / vals.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final byMonth = _monthlyAvgWeights();
    final valid = byMonth.whereType<double>().toList();
    final current = valid.isNotEmpty ? valid.last : WeightStore.weightForDate(appToday);
    final wMin = valid.isEmpty ? current : valid.reduce(math.min);
    final wMax = valid.isEmpty ? current : valid.reduce(math.max);
    final avg = valid.isEmpty
        ? current
        : valid.reduce((a, b) => a + b) / valid.length;
    final first = valid.isNotEmpty ? valid.first : current;
    final diff = current - first;
    final diffText =
        '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg';

    return _YearCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行 ──
          Row(
            children: [
              const Text('体重变化', style: _cardLabelStyle),
              const SizedBox(width: 6),
              Text('${current.toStringAsFixed(1)} kg', style: _cardValueStyle),
              const Spacer(),
              const Text('较起始  ', style: _cardLabelStyle),
              Text(diffText, style: _cardAccentStyle),
            ],
          ),
          const SizedBox(height: 12),
          // ── 折线图 ──
          SizedBox(
            height: 36,
            child: CustomPaint(
              size: const Size(double.infinity, 36),
              painter: _WeightLinePainter(
                monthData: byMonth,
                wMin: wMin,
                wMax: wMax,
                color: AppColors.brand,
                borderColor: AppColors.border,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const _MonthLabels(),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 10),
          // ── 统计行 ──
          Row(
            children: [
              const Text('最低  ', style: _cardLabelStyle),
              Text(valid.isEmpty ? '--' : '${wMin.toStringAsFixed(1)} kg',
                  style: _cardValueStyle),
              const Text('   ·   ', style: _cardLabelStyle),
              const Text('均值  ', style: _cardLabelStyle),
              Text(valid.isEmpty ? '--' : '${avg.toStringAsFixed(1)} kg',
                  style: _cardValueStyle),
              const Text('   ·   ', style: _cardLabelStyle),
              const Text('最高  ', style: _cardLabelStyle),
              Text(valid.isEmpty ? '--' : '${wMax.toStringAsFixed(1)} kg',
                  style: _cardValueStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  final List<double?> monthData;
  final double wMin;
  final double wMax;
  final Color color;
  final Color borderColor;
  _WeightLinePainter({
    required this.monthData,
    required this.wMin,
    required this.wMax,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final range = (wMax - wMin).abs();
    final safeRange = range < 0.01 ? 1.0 : range;
    const padT = 4.0, padB = 4.0;
    final innerH = size.height - padT - padB;

    double xFor(int i) => (i / 11) * size.width;
    double yFor(double w) => padT + (1 - (w - wMin) / safeRange) * innerH;

    // Goal/reference dashed line (wMin baseline)
    final dashPaint = Paint()
      ..color = borderColor.withAlpha(80)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashW = 4.0, dashGap = 3.0;
    double dx = 0;
    while (dx < size.width) {
      canvas.drawLine(Offset(dx, size.height - padB),
          Offset(math.min(dx + dashW, size.width), size.height - padB), dashPaint);
      dx += dashW + dashGap;
    }

    // Collect points
    final points = <Offset>[];
    for (var i = 0; i < monthData.length; i++) {
      final w = monthData[i];
      if (w != null) points.add(Offset(xFor(i), yFor(w)));
    }
    if (points.isEmpty) return;

    // Polyline
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Dots
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i == points.length - 1 ? 3.0 : 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_WeightLinePainter old) =>
      old.monthData != monthData || old.wMin != wMin || old.wMax != wMax;
}

// ── 共用辅助组件 ────────────────────────────────────────
class _YearCard extends StatelessWidget {
  final Widget child;
  const _YearCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        12,
        (i) => Expanded(
          child: Center(
            child: Text('${i + 1}',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

