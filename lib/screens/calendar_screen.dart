import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../health_store.dart';
import '../important_date_store.dart';
import '../todo_store.dart';
import '../weight_store.dart';

// 鈹€鈹€鈹€ Data 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
const _lunarNames = [
  '初一',
  '初二',
  '初三',
  '初四',
  '初五',
  '初六',
  '初七',
  '初八',
  '初九',
  '初十',
  '十一',
  '十二',
  '十三',
  '十四',
  '十五',
  '十六',
  '十七',
  '十八',
  '十九',
  '二十',
  '廿一',
  '廿二',
  '廿三',
  '廿四',
  '廿五',
  '廿六',
  '廿七',
  '廿八',
  '廿九',
  '三十',
];
// 婕旂ず鐢ㄧ殑鍐滃巻鏃ユ湡鐢熸垚鍣細褰撳墠鐗堟湰鍙寜 30 澶╁惊鐜樉绀猴紝鍚庣画鎺ュ叆鐪熷疄鍐滃巻搴撴椂鏇挎崲杩欓噷鍗冲彲銆?
String _lunar(int day) => _lunarNames[(day + 2) % 30];

// 鏃ュ巻鍗曞厓鏍间笂鐨勪笟鍔′簨浠讹細鐢熸棩銆佽妭姘斻€佹櫘閫氫簨浠躲€佸娉ㄥ拰鐢熺悊鏈熸爣璁伴兘浼氭眹鎬诲埌杩欓噷銆?
class _Ev {
  final String? birthday;
  final String? solarTerm;
  final String? eventName;
  final String? note;
  final bool period;
  const _Ev(
      {this.birthday,
      this.solarTerm,
      this.eventName,
      this.note,
      this.period = false});
}

// 鑺傚亣鏃ヤ俊鎭細rest 琛ㄧず璇ユ棩鏈熼渶瑕佹樉绀衡€滀紤鈥濇爣璁帮紝骞舵寜鍋囨棩棰滆壊绐佸嚭銆?
class _Hol {
  final String? name;
  final bool rest;
  final bool work;
  const _Hol({this.name, this.rest = false, this.work = false});
}

// 鏈堣鍥惧簳閮ㄩ潰鏉垮拰骞磋鍥剧粺璁′娇鐢ㄧ殑绀轰緥浣撻噸鏁版嵁銆?
const _weightLog = <int, double>{
  20: 52.1,
  21: 52.4,
  22: 52.0,
  23: 51.8,
  24: 52.2,
  25: 52.6,
  26: 52.4,
};

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

Map<int, _Ev> _eventsForMonth(int year, int month) {
  final map = <int, _Ev>{};

  void merge(
    DateTime date, {
    String? birthday,
    String? eventName,
    String? note,
    bool period = false,
  }) {
    if (date.year != year || date.month != month) return;
    final old = map[date.day];
    map[date.day] = _Ev(
      birthday: birthday ?? old?.birthday,
      eventName: _joinLabel(old?.eventName, eventName),
      note: note ?? old?.note,
      period: period || (old?.period ?? false),
    );
  }

  for (final event in ImportantDateStore.events) {
    var day = _dateOnly(event.startDate);
    while (!day.isAfter(event.endDate)) {
      merge(day, eventName: event.title, note: event.note);
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

  for (var day = 1; day <= DateUtils.getDaysInMonth(year, month); day++) {
    final date = DateTime(year, month, day);
    if (HealthStore.isPeriodDay(date)) {
      merge(date, period: true);
    }
  }

  return map;
}

String? _joinLabel(String? a, String? b) {
  if (b == null || b.isEmpty) return a;
  if (a == null || a.isEmpty) return b;
  if (a.contains(b)) return a;
  return '$a · $b';
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
const _yearWeekLabels = ['一', '二', '三', '四', '五', '六', '日'];

DateTime get _todayDate {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

int get _startDay => DateTime(_todayDate.year, _todayDate.month, 1).weekday % 7;
int get _daysCount =>
    DateUtils.getDaysInMonth(_todayDate.year, _todayDate.month);
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
    '十二月'
  ];
  return labels[month - 1];
}

// 椤堕儴瑙嗗浘鍒囨崲锛氭湀 / 鍛?/ 鏃?/ 骞?鍥涚灞曠ず褰㈡€併€?
enum _View { month, week, day, year }

// 鈹€鈹€鈹€ Main Screen 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 椤甸潰绾х姸鎬侀泦涓湪杩欓噷锛氬綋鍓嶈鍥惧拰閫変腑鏃ユ湡銆?
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
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _todayTimer =
        Timer(tomorrow.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        final now = _todayDate;
        if (_displayedMonth.year == now.year &&
            _displayedMonth.month == now.month) {
          _selected = _today;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ImportantDateStore.version,
        HealthStore.periodRecords,
        HealthStore.fitnessRecords,
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
                  onView: (v) => setState(() => _view = v)),
              Expanded(
                // 鏍规嵁椤堕儴閫夋嫨鍒囨崲涓嶅悓瑙嗗浘锛涢€変腑鏃ユ湡閫氳繃鍥炶皟鍦ㄧ埗缁勪欢涓繚鎸佸悓姝ャ€?
                child: switch (_view) {
                  _View.month => _MonthView(
                      year: _displayedMonth.year,
                      month: _displayedMonth.month,
                      selected: _selected,
                      onSelect: (d) => setState(() => _selected = d),
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
                      onSelect: (d) => setState(() => _selected = d),
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

// 鈹€鈹€鈹€ Header 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
class _Header extends StatelessWidget {
  final _View view;
  final DateTime displayDate;
  final VoidCallback? onMonthTap;
  final ValueChanged<_View> onView;
  const _Header(
      {required this.view,
      required this.displayDate,
      required this.onMonthTap,
      required this.onView});

  @override
  Widget build(BuildContext context) {
    final titleText = view == _View.year
        ? '${displayDate.year}年'
        : _monthLabel(displayDate.month);
    final showSubtitle = view != _View.year;

    // 鏃ュ巻鏍囬鍖猴細宸︿晶灞曠ず鏈堜唤鍜屽啘鍘嗗勾浠斤紝鍙充晶鎵挎媴瑙嗗浘鍒囨崲鍜屾柊澧炲叆鍙ｃ€?
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                if (showSubtitle)
                  Text('${displayDate.year}年',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Spacer(),
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

// 鈹€鈹€鈹€ Segmented Control 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
class _SegControl extends StatelessWidget {
  final List<String> options;
  final String active;
  final ValueChanged<String> onTap;
  const _SegControl(
      {required this.options, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 杞婚噺鍒嗘鎺т欢锛岀敤 AnimatedContainer 琛ㄨ揪褰撳墠閫変腑椤圭殑鍙嶉銆?
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

// 鈹€鈹€鈹€ Month View 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
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
    return Container(
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
                            ? AppColors.brand
                            : isSelected
                                ? AppColors.brandLight
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
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  // 鎸夊浐瀹氳楂樻樉寮忔瀯寤烘棩鍘嗚锛岄伩鍏?GridView 鍦ㄤ笉鍚屽睆骞曞搴︿笅浜х敓楂樺害婧㈠嚭銆?
  Widget _buildCalendarGrid(
    List<_MonthDay> cells, {
    double? maxHeight,
  }) {
    final preferredRowHeight = switch (_mode) {
      _MonthCalendarMode.week => 62.0,
      _MonthCalendarMode.month => 58.0,
      _MonthCalendarMode.detail => 75.0,
    };
    final today = _todayDate;
    final events = _eventsForMonth(widget.year, widget.month);
    final monthStartDay = DateTime(widget.year, widget.month, 1).weekday % 7;
    final rowCount = (cells.length / 7).ceil();
    final rowHeight = maxHeight == null
        ? preferredRowHeight
        : math.min(preferredRowHeight, maxHeight / rowCount);
    Widget buildRow(int rowIdx) {
      final start = rowIdx * 7;
      final end = (start + 7).clamp(0, cells.length);
      final rowCells = List<_MonthDay>.from(cells.sublist(start, end));
      while (rowCells.length < 7) {
        rowCells.add(const _MonthDay(day: 0, inCurrentMonth: false));
      }

      return Row(
        children: rowCells
            .map((cell) => Expanded(
                  child: cell.day == 0
                      ? const SizedBox()
                      : _DayCell(
                          day: cell.day,
                          selected: cell.inCurrentMonth &&
                              cell.day == widget.selected,
                          today: cell.inCurrentMonth &&
                              widget.year == today.year &&
                              widget.month == today.month &&
                              cell.day == today.day,
                          ev: cell.inCurrentMonth ? events[cell.day] : null,
                          hol: cell.inCurrentMonth
                              ? _holidayForDate(DateTime(
                                  widget.year,
                                  widget.month,
                                  cell.day,
                                ))
                              : null,
                          monthStartDay: monthStartDay,
                          showLabels: _mode == _MonthCalendarMode.detail &&
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
        // 鏄熸湡鏍囬琛屻€?
        if (_mode != _MonthCalendarMode.week) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
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
          flex: _mode == _MonthCalendarMode.detail ? 5 : 4,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _handleVerticalCalendarDrag(event.scrollDelta.dy);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _gridDragOffset = 0,
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
              onVerticalDragUpdate: (details) {
                _gridDragOffset += details.primaryDelta ?? 0;
                if (_gridDragOffset < -24) {
                  _gridDragOffset = 0;
                  _handleVerticalCalendarDrag(-1);
                } else if (_gridDragOffset > 24) {
                  _gridDragOffset = 0;
                  _handleVerticalCalendarDrag(1);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _mode == _MonthCalendarMode.week
                          ? _buildWeekCalendarStrip()
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
        Expanded(
          child: _CalendarInfoPanels(
            selectedDate: DateTime(widget.year, widget.month, widget.selected),
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

// 鈹€鈹€鈹€ Day Cell 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
class _DayCell extends StatelessWidget {
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
    // 鍗曚釜鏃ユ湡鏍兼牴鎹€滀粖澶?/ 閫変腑 / 鑺傚亣鏃?/ 鐢熺悊鏈?/ 浜嬩欢鈥濈粍鍚堝喅瀹氶鑹蹭笌瑙掓爣銆?
    final inPeriod = ev?.period == true;
    final isWeekend = ((day + monthStartDay - 1) % 7 == 0);
    final lunarStr = ev?.solarTerm ?? _lunar(day);
    final label = hol?.name ?? ev?.eventName ?? ev?.birthday;
    final labelColor = hol?.name != null
        ? AppColors.holiday
        : ev?.birthday != null
            ? AppColors.birthday
            : ev?.eventName != null
                ? AppColors.event
                : null;
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
            : ev?.solarTerm != null
                ? AppColors.event
                : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        color: inPeriod ? AppColors.periodBg : Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: today
                        ? AppColors.brand
                        : selected
                            ? AppColors.brandLight
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
                            fontWeight:
                                today ? FontWeight.bold : FontWeight.normal,
                          )),
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
            SizedBox(height: showLabels ? 6 : 2),
            if (showLabels && label != null)
              Container(
                constraints: const BoxConstraints(maxWidth: 58),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: (labelColor ?? AppColors.brand).withAlpha(36),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: labelColor,
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ev?.birthday != null) _Dot(color: AppColors.birthday),
                  if (ev?.eventName != null) _Dot(color: AppColors.event),
                  if (inPeriod) _Dot(color: AppColors.period),
                ],
              ),
          ],
        ),
      ),
    );
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

// 鈹€鈹€鈹€ Selected Day Plans 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
class _SelectedDayPlans extends StatelessWidget {
  final int day;
  const _SelectedDayPlans({required this.day});

  @override
  Widget build(BuildContext context) {
    final ev = _eventsForMonth(_todayDate.year, _todayDate.month)[day];
    final lunarStr = ev?.solarTerm ?? _lunar(day);
    final isToday = day == _today;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$day日',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      color: isToday ? AppColors.brand : AppColors.textPrimary,
                    )),
                const SizedBox(width: 8),
                Text(lunarStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: ev?.solarTerm != null
                          ? AppColors.event
                          : AppColors.textSecondary,
                    )),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showAddTodoDialog(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight.withAlpha(150),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.brand),
                        SizedBox(width: 3),
                        Text('待办事项',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.brand,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<TodoItem>>(
              valueListenable: TodoStore.items,
              builder: (context, todos, _) {
                if (todos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('暂无待办',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.border)),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < todos.length; i++)
                      _TodoPlanRow(index: i + 1, todo: todos[i]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTodoDialog(BuildContext context) async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('添加待办事项',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              )),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '待办内容',
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
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('添加',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        );
      },
    );
    if (added == true) {
      TodoStore.add(controller.text);
    }
    controller.dispose();
  }
}

class _TodoPlanRow extends StatelessWidget {
  final int index;
  final TodoItem todo;
  const _TodoPlanRow({required this.index, required this.todo});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  fontSize: 15,
                  height: 1.2,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                )),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => TodoStore.remove(todo.id),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Icon(Icons.close, size: 16, color: AppColors.border),
              ),
            ),
          ),
        ],
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
            _TodoInfoCard(onAdd: () => _showAddTodoDialog(context)),
            const SizedBox(height: 12),
            _UpcomingInfoCard(
              onAdd: () => _showImportantDateDialog(context, selectedDate),
              onDelete: (item) => _confirmRemoveImportantDate(context, item),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTodoDialog(BuildContext context) async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('添加待办事项',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              )),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '待办内容',
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
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('添加',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        );
      },
    );
    if (added == true) {
      TodoStore.add(controller.text);
    }
    controller.dispose();
  }

  Future<void> _showImportantDateDialog(
    BuildContext context,
    DateTime selectedDate,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ImportantDateDialog(initialDate: selectedDate),
    );
  }

  Future<void> _confirmRemoveImportantDate(
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
          content: Text('确定删除「${item.title}」吗？记录页中的对应信息也会同步移除。',
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
    }
  }
}

class _TodoInfoCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _TodoInfoCard({required this.onAdd});

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
                style: TextStyle(
                    fontSize: 15, height: 1.2, color: AppColors.border));
          }
          final visible = todos.take(3).toList();
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++)
                _TodoPlanRow(index: i + 1, todo: visible[i]),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingInfoCard extends StatelessWidget {
  final VoidCallback onAdd;
  final ValueChanged<UpcomingImportantDate> onDelete;
  const _UpcomingInfoCard({
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      title: '近期时间 · 未来 2 个月',
      action: GestureDetector(
        onTap: onAdd,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.brand),
            SizedBox(width: 2),
            Text('添加',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: ImportantDateStore.version,
        builder: (context, _, __) {
          final items = ImportantDateStore.upcomingWithinMonths(
            today: DateTime.now(),
          );
          if (items.isEmpty) {
            return const Text('近两个月暂无重要时间',
                style: TextStyle(
                    fontSize: 15, height: 1.2, color: AppColors.border));
          }
          return Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _UpcomingImportantRow(
                  item: items[i],
                  last: i == items.length - 1,
                  onDelete: () => onDelete(items[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingImportantRow extends StatelessWidget {
  final UpcomingImportantDate item;
  final bool last;
  final VoidCallback onDelete;
  const _UpcomingImportantRow({
    required this.item,
    required this.last,
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
    final days = item.date.difference(_todayDate).inDays;
    final dayText = days == 0
        ? '今天'
        : days == 1
            ? '明天'
            : '$days 天后';
    return Container(
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
                        fontSize: 15,
                        height: 1.2,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 3),
                Text('${item.dateText} · ${item.subtitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(dayText,
              style: TextStyle(fontSize: 15, height: 1.2, color: item.color)),
          Tooltip(
            message: '删除',
            child: GestureDetector(
              onTap: onDelete,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.holiday),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportantDateDialog extends StatefulWidget {
  final DateTime initialDate;

  const _ImportantDateDialog({required this.initialDate});

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

  @override
  void initState() {
    super.initState();
    _startDate = dateOnly(widget.initialDate);
    _endDate = _startDate;
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

  String get _titleHint {
    switch (_type) {
      case ImportantDateType.event:
        return '????';
      case ImportantDateType.birthday:
        return '????';
      case ImportantDateType.anniversary:
        return '?????';
    }
  }

  String _typeText(ImportantDateType type) {
    switch (type) {
      case ImportantDateType.event:
        return '????';
      case ImportantDateType.birthday:
        return '??';
      case ImportantDateType.anniversary:
        return '???';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}?${date.month}?${date.day}?';

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
      setState(() => _error = '?????');
      return;
    }

    switch (_type) {
      case ImportantDateType.event:
        ImportantDateStore.saveEvent(
          title: title,
          startDate: _startDate,
          endDate: _eventSpansDays ? _endDate : _startDate,
          note: _noteCtrl.text.trim(),
        );
        break;
      case ImportantDateType.birthday:
        ImportantDateStore.saveBirthday(name: title, solar: _startDate);
        break;
      case ImportantDateType.anniversary:
        ImportantDateStore.saveAnniversary(name: title, solar: _startDate);
        break;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEvent = _type == ImportantDateType.event;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('??????',
                    style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: ImportantDateType.values.map((type) {
                    final selected = type == _type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _type = type;
                          _error = null;
                          if (_type != ImportantDateType.event) {
                            _eventSpansDays = false;
                            if (_startDate.isAfter(_todayDate)) {
                              _startDate = _todayDate;
                            }
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
                  label: isEvent ? '????' : '??',
                  text: _formatDate(_startDate),
                  color: _color,
                  onTap: () => _pickDate(
                    initial: _startDate,
                    allowFuture: isEvent,
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
                      label: '????',
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
                    hint: '??????',
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
                  child: const Text('??'),
                ),
              ],
            ),
          ),
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
          option('??', false),
          option('????', true),
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
        borderRadius: BorderRadius.circular(12),
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
                      fontSize: 15,
                      height: 1.2,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
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

// 鈹€鈹€鈹€ Week View 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
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
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dy < 0) {
          onExpandToMonth();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 240) {
            onExpandToMonth();
          }
        },
        child: Column(
          children: [
            Container(
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
                                    ? AppColors.brand
                                    : isSelected
                                        ? AppColors.brandLight
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
                                    fontWeight: isToday
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
            Expanded(
              child: _CalendarInfoPanels(
                selectedDate: DateTime(year, month, selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _lunarDateText(DateTime date) {
  const lunarMonths = [
    '正月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '冬月',
    '腊月',
  ];
  final lunarMonth = lunarMonths[(date.month - 1).clamp(0, 11).toInt()];
  return '农历$lunarMonth${_lunar(date.day)}';
}

String _seasonStemText(DateTime date, _Ev? ev) {
  final term = ev?.solarTerm ?? _seasonNameForMonth(date.month);
  final termStart = switch (term) {
    '夏至' => DateTime(date.year, date.month, 24),
    '春分' => DateTime(date.year, date.month, 20),
    '秋分' => DateTime(date.year, date.month, 23),
    '冬至' => DateTime(date.year, date.month, 22),
    _ => DateTime(date.year, date.month, 4),
  };
  final termDay = (date.difference(termStart).inDays + 1).clamp(1, 15).toInt();
  return '$term · 第$termDay 日  |   甲子日 · 木';
}

String _seasonNameForMonth(int month) {
  if (month == 3 || month == 4) return '春分';
  if (month == 5 || month == 6) return '夏至';
  if (month >= 7 && month <= 9) return '秋分';
  if (month >= 10 && month <= 12) return '冬至';
  return '立春';
}

class _DayView extends StatelessWidget {
  final int year;
  final int month;
  final int selected;
  final ValueChanged<int> onSelect;
  const _DayView({
    required this.year,
    required this.month,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // 鏃ヨ鍥捐仛鐒﹂€変腑鏃ユ湡锛岄《閮ㄥ彲鍓嶅悗鍒囨崲鏃ユ湡锛屼笅鏂瑰睍绀哄叏澶╂椂闂磋酱銆?
    final date = DateTime(year, month, selected);
    final lunarStr = _lunarDateText(date);
    final dayOfWeek = date.weekday % 7;
    const weekNames = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final daysCount = DateUtils.getDaysInMonth(year, month);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DayNavButton(
                      icon: Icons.chevron_left,
                      enabled: selected > 1,
                      onPressed: () => onSelect(selected - 1),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 118,
                      child: Center(
                        child: Text('$selected',
                            style: const TextStyle(
                              fontSize: 78,
                              height: 0.9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.holiday,
                            )),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 72,
                      color: AppColors.border,
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(weekNames[dayOfWeek],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 10),
                          Text(lunarStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    _DayNavButton(
                      icon: Icons.chevron_right,
                      enabled: selected < daysCount,
                      onPressed: () => onSelect(selected + 1),
                    ),
                  ],
                ),
              ),
            ],
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

// 鈹€鈹€鈹€ Year View 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
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
    // 骞磋鍥炬槸姒傝椤碉細涓婃柟鏄剧ず缁熻鍗＄墖锛屼笅鏂圭敤杩蜂綘鏈堝巻灞曠ず鍏ㄥ勾浜嬩欢鍒嗗竷銆?
    final today = _todayDate;
    final months = [
      for (var month = 1; month <= 12; month++)
        _MiniMonthData(
          '$month月',
          DateUtils.getDaysInMonth(year, month),
          DateTime(year, month, 1).weekday - 1,
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
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final veryNarrow = constraints.maxWidth < 330;
                return GridView.builder(
                  itemCount: months.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: veryNarrow ? 2 : 3,
                    crossAxisSpacing: compact ? 8 : 12,
                    mainAxisSpacing: compact ? 12 : 14,
                    mainAxisExtent: veryNarrow
                        ? 236
                        : compact
                            ? 228
                            : 236,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final month = months[index];
                    return _MiniMonth(
                      data: month,
                      isCurrent: year == today.year && index == today.month - 1,
                      onDoubleTap: () => onOpenMonth(index + 1),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),
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
    if (holiday?.rest == true || holiday?.work == true) {
      add(date, _YearEventType.holiday);
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

enum _YearEventType { birthday, anniversary, event, holiday, period }

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
  final VoidCallback onDoubleTap;

  const _MiniMonth({
    required this.data,
    required this.isCurrent,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    // 骞磋鍥鹃噷鐨勮糠浣犳湀鍘嗛噰鐢ㄥ崱鐗囧紡鎺掔増锛屼紭鍏堜繚璇佹暣骞存祻瑙堟椂鐨勫彲璇绘€с€?
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
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? AppColors.brandLight : Colors.white,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(data.name,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? AppColors.brand : AppColors.textPrimary,
                  )),
              const SizedBox(height: 6),
              Row(
                children: List.generate(7, (index) {
                  final weekend = index == 5 || index == 6;
                  return Expanded(
                    child: Center(
                      child: Text(
                        _yearWeekLabels[index],
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          color: weekend
                              ? AppColors.brand
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellHeight = constraints.maxHeight / 6;
                    final stackHeight = math.min(26.0, cellHeight);
                    final numberSize = math.max(17.0, stackHeight - 5);
                    final numberFontSize = stackHeight < 24 ? 11.0 : 13.0;

                    return Column(
                      children: List.generate(6, (rowIndex) {
                        final row = cells.skip(rowIndex * 7).take(7).toList();
                        return Expanded(
                          child: Row(
                            children: List.generate(7, (columnIndex) {
                              final d = row[columnIndex];
                              if (d == null) {
                                return const Expanded(child: SizedBox());
                              }
                              final types =
                                  evMap[d] ?? const <_YearEventType>{};
                              final leftDay = columnIndex == 0
                                  ? null
                                  : row[columnIndex - 1];
                              final rightDay = columnIndex == 6
                                  ? null
                                  : row[columnIndex + 1];
                              final periodSelected =
                                  types.contains(_YearEventType.period);
                              final eventSelected =
                                  types.contains(_YearEventType.event);
                              final periodLeft = periodSelected &&
                                  _hasYearEvent(
                                      evMap, leftDay, _YearEventType.period);
                              final periodRight = periodSelected &&
                                  _hasYearEvent(
                                      evMap, rightDay, _YearEventType.period);
                              final eventLeft = eventSelected &&
                                  _hasYearEvent(
                                      evMap, leftDay, _YearEventType.event);
                              final eventRight = eventSelected &&
                                  _hasYearEvent(
                                      evMap, rightDay, _YearEventType.event);
                              final isToday = isCurrent && d == _today;
                              final weekend =
                                  columnIndex == 5 || columnIndex == 6;
                              final textColor = isToday
                                  ? Colors.white
                                  : types.contains(_YearEventType.birthday)
                                      ? AppColors.birthday
                                      : types.contains(_YearEventType.holiday)
                                          ? AppColors.holiday
                                          : weekend
                                              ? AppColors.brand
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
                                            color: AppColors.periodBg,
                                            extendLeft: periodLeft,
                                            extendRight: periodRight,
                                          ),
                                        if (eventSelected)
                                          _YearRangeBand(
                                            color: AppColors.eventLight
                                                .withAlpha(120),
                                            extendLeft: eventLeft,
                                            extendRight: eventRight,
                                          ),
                                        Align(
                                          alignment: Alignment.topCenter,
                                          child: Container(
                                            width: 23,
                                            height: numberSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isToday
                                                  ? AppColors.brand
                                                  : Colors.transparent,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$d',
                                                style: TextStyle(
                                                  fontSize: numberFontSize,
                                                  height: 1,
                                                  color: textColor,
                                                  fontWeight: isToday ||
                                                          types.isNotEmpty
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: _YearEventDots(types: types),
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
    );
  }
}

class _YearEventDots extends StatelessWidget {
  final Set<_YearEventType> types;

  const _YearEventDots({required this.types});

  Color _colorFor(_YearEventType type) {
    switch (type) {
      case _YearEventType.birthday:
        return AppColors.birthday;
      case _YearEventType.anniversary:
      case _YearEventType.event:
        return AppColors.event;
      case _YearEventType.holiday:
        return AppColors.holiday;
      case _YearEventType.period:
        return AppColors.period;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      if (types.contains(_YearEventType.birthday)) _YearEventType.birthday,
      if (types.contains(_YearEventType.anniversary))
        _YearEventType.anniversary,
      if (types.contains(_YearEventType.event)) _YearEventType.event,
      if (types.contains(_YearEventType.holiday)) _YearEventType.holiday,
      if (types.contains(_YearEventType.period)) _YearEventType.period,
    ].take(3).toList();

    return SizedBox(
      height: 5,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in visible)
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorFor(type),
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
            margin: EdgeInsets.only(
              left: extendLeft ? 0 : 7,
              right: extendRight ? 0 : 7,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(extendLeft ? 0 : 99),
                right: Radius.circular(extendRight ? 0 : 99),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(90),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
    final currentWeight = WeightStore.todayWeight;
    final yearlyWeights = WeightStore.weights.value.entries
        .where((entry) => WeightStore.dateFromKey(entry.key).year == year)
        .map((entry) => entry.value)
        .toList();
    final minWeight = yearlyWeights.isEmpty
        ? currentWeight
        : yearlyWeights.reduce((a, b) => a < b ? a : b);
    final fitnessDays = HealthStore.fitnessDaysInYear(year);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: '⚖',
              value: currentWeight.toStringAsFixed(1),
              label: '当前体重 kg',
              color: AppColors.brand,
              sub: '全年最低 ${minWeight.toStringAsFixed(1)} kg',
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            height: 42,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: '🔥',
              value: '$fitnessDays天',
              label: '健身打卡',
              color: AppColors.event,
              sub: '本年目标 150天',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  final String sub;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color,
      required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
