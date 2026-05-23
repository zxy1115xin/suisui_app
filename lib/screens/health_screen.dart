import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../app_colors.dart';
import '../health_store.dart';
import '../storage_service.dart';
import '../weight_store.dart';

// 数据区。
const _fitnessTypes = ['跑步', '瑜伽', '力量', '骑行', '游泳', '走路'];
const _healthAccent = Color(0xFFC8765A);
const _healthAccentLight = Color(0xFFF0D5C8);

class _PeriodRecord {
  final int id;
  final String start;
  final String end;
  final int days;
  final int cycle;

  const _PeriodRecord({
    required this.id,
    required this.start,
    required this.end,
    required this.days,
    required this.cycle,
  });
}

class _PeriodWindow {
  final DateTime start;
  final DateTime end;
  final int cycle;
  final bool predicted;

  const _PeriodWindow({
    required this.start,
    required this.end,
    required this.cycle,
    required this.predicted,
  });
}

String _formatPeriodDate(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日';

DateTime? _parsePeriodDate(String value) {
  final full = RegExp(r'^(\d{4})年(0?[1-9]|1[0-2])月(0?[1-9]|[12]\d|3[01])日$')
      .firstMatch(value.trim());
  final short = RegExp(r'^(0?[1-9]|1[0-2])月(0?[1-9]|[12]\d|3[01])日$')
      .firstMatch(value.trim());
  final year = full == null ? DateTime.now().year : int.parse(full.group(1)!);
  final month = int.parse((full ?? short)?.group(full == null ? 1 : 2) ?? '0');
  final day = int.parse((full ?? short)?.group(full == null ? 2 : 3) ?? '0');
  if (month < 1 || month > 12) return null;
  final maxDay = DateUtils.getDaysInMonth(year, month);
  if (day < 1 || day > maxDay) return null;
  return DateTime(year, month, day);
}

bool _isSameMonth(DateTime value, DateTime month) =>
    value.year == month.year && value.month == month.month;

// 页面主体。
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool? _showFitnessModule;
  bool? _showPeriodModule;
  bool? _showWeightModule;

  bool get _fitnessVisible => _showFitnessModule ?? true;
  bool get _periodVisible => _showPeriodModule ?? true;
  bool get _weightVisible => _showWeightModule ?? true;

  // 控制健身卡片中“打卡面板”和“周/月视图”的展开状态。
  bool _showCheckin = false;
  bool _showMonthView = false;
  DateTime _checkinDate = appToday;
  String _selFitness = '跑步';
  double _hours = 1.0;

  int get _calStartDay =>
      DateTime(_todayDate.year, _todayDate.month, 1).weekday % 7;
  int get _calDays =>
      DateUtils.getDaysInMonth(_todayDate.year, _todayDate.month);
  int get _todayDay => _todayDate.day;
  List<DateTime> get _recent7Dates =>
      List.generate(7, (i) => _todayDate.subtract(Duration(days: 6 - i)));

  Map<int, List<dynamic>> get _monthLog {
    final records =
        HealthStore.fitnessLogForMonth(_todayDate.year, _todayDate.month);
    return {
      for (final entry in records.entries)
        entry.key: [entry.value.type, entry.value.minutes],
    };
  }

  // 本月打卡总天数直接来自记录条数。
  int get _totalDays => _monthLog.length;

  // 汇总本月所有运动分钟数，用于卡片左上角展示运动总时间。
  int get _totalMinutes => _monthLog.values
      .map((log) => log[1] as int)
      .fold(0, (sum, minutes) => sum + minutes);

  // 生理期状态：列表、开始/结束日期以及当前正在编辑的字段。
  bool _showPeriodHistory = false;
  DateTime get _todayDate => appToday;

  List<_PeriodRecord> get _safePeriodRecords {
    final records = [
      for (final record in HealthStore.periodRecords.value)
        _PeriodRecord(
          id: record.id,
          start: _formatPeriodDate(record.start),
          end: _formatPeriodDate(record.end),
          days: record.days,
          cycle: record.cycle,
        ),
    ];
    records.sort((a, b) {
      final aDate = _parsePeriodDate(a.start) ?? DateTime(1900);
      final bDate = _parsePeriodDate(b.start) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    return records;
  }

  static const _keyFitness = 'health_show_fitness';
  static const _keyPeriod = 'health_show_period';
  static const _keyWeight = 'health_show_weight';

  @override
  void initState() {
    super.initState();
    _checkinDate = _todayDate;
    _showFitnessModule = StorageService.getBool(_keyFitness);
    _showPeriodModule = StorageService.getBool(_keyPeriod);
    _showWeightModule = StorageService.getBool(_keyWeight);
    HealthStore.periodRecords.addListener(_onPeriodRecordsChanged);
    HealthStore.fitnessRecords.addListener(_onFitnessRecordsChanged);
  }

  void _onPeriodRecordsChanged() {
    if (mounted) setState(() {});
  }

  void _onFitnessRecordsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HealthStore.periodRecords.removeListener(_onPeriodRecordsChanged);
    HealthStore.fitnessRecords.removeListener(_onFitnessRecordsChanged);
    super.dispose();
  }

  String _formatDuration(double h) {
    if (h == 0) return '未记录';
    if (h < 1) return '${(h * 60).round()}分钟';
    if (h == h.truncate()) return '${h.toInt()}小时';
    return '${h.toStringAsFixed(1)}小时';
  }

  String _formatMinutes(int minutes) => _formatDuration(minutes / 60);

  void _showModuleSettings() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭模块设置',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          alignment: Alignment.topRight,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 38, right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: StatefulBuilder(
                    builder: (context, modalSetState) {
                      Widget row({
                        required String label,
                        required IconData icon,
                        required bool value,
                        required ValueChanged<bool> onChanged,
                      }) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          child: Row(
                            children: [
                              Icon(icon, size: 17, color: _healthAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: 0.78,
                                child: Switch.adaptive(
                                  value: value,
                                  onChanged: (next) {
                                    onChanged(next);
                                    modalSetState(() {});
                                  },
                                  activeThumbColor: _healthAccent,
                                  activeTrackColor: _healthAccentLight,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        width: 176,
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '模块显示',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            row(
                              label: '健身打卡',
                              icon: Icons.fitness_center,
                              value: _fitnessVisible,
                              onChanged: (next) {
                                StorageService.setBool(_keyFitness, next);
                                setState(() {
                                  _showFitnessModule = next;
                                  if (!next) {
                                    _showCheckin = false;
                                    _showMonthView = false;
                                  }
                                });
                              },
                            ),
                            row(
                              label: '生理期',
                              icon: Icons.calendar_month,
                              value: _periodVisible,
                              onChanged: (next) {
                                StorageService.setBool(_keyPeriod, next);
                                setState(() => _showPeriodModule = next);
                              },
                            ),
                            row(
                              label: '体重记录',
                              icon: Icons.monitor_weight_outlined,
                              value: _weightVisible,
                              onChanged: (next) {
                                StorageService.setBool(_keyWeight, next);
                                setState(() => _showWeightModule = next);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _cancelCheckinForDate(DateTime date) {
    HealthStore.removeFitnessRecord(date);
    setState(() {
      if (DateUtils.isSameDay(_checkinDate, date)) {
        _showCheckin = false;
      }
    });
  }

  void _toggleFitnessView() {
    setState(() {
      _showCheckin = false;
      _showMonthView = !_showMonthView;
    });
  }

  void _handleFitnessCardBlankTap() {
    if (!_showCheckin && !_showMonthView) return;
    setState(() {
      _showCheckin = false;
      if (_showMonthView) {
        _showMonthView = false;
      }
    });
  }

  void _openCheckinForDate(DateTime date) {
    final existingLog = HealthStore.fitnessRecordForDate(date);
    setState(() {
      _checkinDate = DateTime(date.year, date.month, date.day);
      _showCheckin = true;
      _showMonthView = false;
      if (existingLog != null) {
        _selFitness = existingLog.type;
        _hours = existingLog.minutes / 60;
      } else {
        _selFitness = _fitnessTypes.first;
        _hours = 1.0;
      }
    });
  }

  // 根据日期推算星期标签，服务于近 7 天打卡条。
  String _weekLabel(DateTime date) {
    const names = ['日', '一', '二', '三', '四', '五', '六'];
    final weekday = date.weekday % 7;
    return names[weekday];
  }

  _PeriodWindow? _periodWindowForMonth(DateTime month) {
    final sorted = _safePeriodRecords;
    final sameMonthRecords = sorted.where((record) {
      final start = _parsePeriodDate(record.start);
      return start != null && _isSameMonth(start, month);
    }).toList();
    if (sameMonthRecords.isNotEmpty) {
      final record = sameMonthRecords.first;
      final start = _parsePeriodDate(record.start)!;
      final end = _parsePeriodDate(record.end) ??
          start.add(Duration(days: math.max(record.days, 1) - 1));
      return _PeriodWindow(
        start: start,
        end: end,
        cycle: record.cycle,
        predicted: false,
      );
    }

    if (sorted.isEmpty) return null;
    final latest = sorted.first;
    final latestStart = _parsePeriodDate(latest.start);
    if (latestStart == null) return null;

    var predictedStart = latestStart;
    final cycle = latest.cycle;
    final days = math.max(latest.days, 1);
    while (predictedStart.isBefore(DateTime(month.year, month.month, 1))) {
      predictedStart = predictedStart.add(Duration(days: cycle));
    }
    while (predictedStart.year > month.year ||
        predictedStart.month > month.month) {
      predictedStart = predictedStart.subtract(Duration(days: cycle));
    }
    return _PeriodWindow(
      start: predictedStart,
      end: predictedStart.add(Duration(days: days - 1)),
      cycle: cycle,
      predicted: true,
    );
  }

  _PeriodWindow? get _currentPeriodWindow => _periodWindowForMonth(_todayDate);

  _PeriodRecord? get _currentPeriodRecord {
    final records = _safePeriodRecords.where((record) {
      final start = _parsePeriodDate(record.start);
      return start != null && _isSameMonth(start, _todayDate);
    }).toList();
    return records.isEmpty ? null : records.first;
  }

  String get _periodStatusText {
    final window = _currentPeriodWindow;
    if (window == null) return '暂无生理期预测';
    final today = _todayDate;
    if (today.isBefore(window.start)) {
      return '距离生理期还有 ${window.start.difference(today).inDays} 天';
    }
    if (today.isAfter(window.end)) return '本月生理期已结束';
    return '生理期第 ${today.difference(window.start).inDays + 1} 天';
  }

  String get _currentPeriodStartText {
    final window = _currentPeriodWindow;
    if (window == null) return '--';
    return '${window.start.month}月${window.start.day}日';
  }

  String get _currentPeriodEndText {
    final window = _currentPeriodWindow;
    if (window == null) return '--';
    return '${window.end.month}月${window.end.day}日';
  }

  int get _currentCycleLength {
    final sorted = _safePeriodRecords;
    return sorted.isEmpty ? 28 : sorted.first.cycle;
  }

  int get _currentPeriodDays {
    final sorted = _safePeriodRecords;
    return sorted.isEmpty ? 5 : math.max(sorted.first.days, 1);
  }

  int get _todayCycleDay {
    final window = _currentPeriodWindow;
    if (window == null) return 0;
    final diff = _todayDate.difference(window.start).inDays;
    if (diff < 0) return 0;
    return (diff + 1).clamp(1, _currentCycleLength);
  }

  String get _currentPhaseName {
    final day = _todayCycleDay;
    if (day == 0) return '--';
    final cycle = _currentCycleLength;
    final periodDays = _currentPeriodDays.clamp(1, 12);
    final follEnd = (cycle * 0.46).round().clamp(periodDays + 2, cycle - 6);
    final ovEnd = (follEnd + 3).clamp(follEnd + 1, cycle - 3);
    if (day <= periodDays) return '月经期';
    if (day <= follEnd) return '卵泡期';
    if (day <= ovEnd) return '排卵期';
    return '黄体期';
  }

  String get _nextPeriodStartText {
    final window = _currentPeriodWindow;
    if (window == null) return '--';
    final next = window.start.add(Duration(days: _currentCycleLength));
    return '${next.month}月${next.day}日';
  }

  Future<void> _editCurrentPeriodDate({required bool editingStart}) async {
    final record = _currentPeriodRecord;
    final window = _currentPeriodWindow;
    final currentStart =
        _parsePeriodDate(record?.start ?? '') ?? window?.start ?? _todayDate;
    final currentEnd = _parsePeriodDate(record?.end ?? '') ??
        window?.end ??
        currentStart.add(const Duration(days: 4));
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭日期选择',
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: Center(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _PeriodDateWheelSheet(
                    initial: editingStart ? currentStart : currentEnd,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    if (!mounted) return;

    final durationDays =
        math.max(currentEnd.difference(currentStart).inDays + 1, 1);
    var nextStart = editingStart ? picked : currentStart;
    var nextEnd = editingStart ? currentEnd : picked;
    if (nextEnd.isBefore(nextStart)) {
      if (editingStart) {
        nextEnd = nextStart.add(Duration(days: durationDays - 1));
      } else {
        nextStart = nextEnd;
      }
    }

    _savePeriodRecord(
      id: record?.id,
      start: _formatPeriodDate(nextStart),
      end: _formatPeriodDate(nextEnd),
      cycle: record?.cycle ?? window?.cycle ?? 28,
    );
  }

  void _savePeriodRecord({
    int? id,
    required String start,
    required String end,
    required int cycle,
  }) {
    final startDate = _parsePeriodDate(start);
    final endDate = _parsePeriodDate(end);
    if (startDate == null || endDate == null) return;

    HealthStore.savePeriod(
      id: id,
      start: startDate,
      end: endDate,
      cycle: cycle,
    );

    if (mounted) setState(() {});
  }

  void _deletePeriodRecord(int id) {
    HealthStore.removePeriod(id);
    if (mounted) setState(() {});
  }

  Widget _buildMonthGrid() {
    // 健身月视图也复用日历网格思路：先补空白格，再补 1-30 日。
    final cells = <int?>[
      ...List<int?>.filled(_calStartDay, null),
      ...List.generate(_calDays, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    const rowHeight = 58.0;
    final rowCount = cells.length ~/ 7;
    return Column(
      children: List.generate(rowCount, (rowIdx) {
        final start = rowIdx * 7;
        final rowCells = cells.sublist(start, start + 7);
        return SizedBox(
          height: rowHeight,
          child: Row(
            children: rowCells.map((d) {
              if (d == null) return const Expanded(child: SizedBox());
              final date = DateTime(_todayDate.year, _todayDate.month, d);
              final done = _monthLog.containsKey(d);
              final isToday = d == _todayDay;
              final isEditing =
                  _showCheckin && DateUtils.isSameDay(date, _checkinDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => _openCheckinForDate(date),
                  onDoubleTap: done ? () => _cancelCheckinForDate(date) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? _healthAccent : Colors.transparent,
                          border: isEditing
                              ? Border.all(color: _healthAccent, width: 1.5)
                              : (isToday && !done
                                  ? Border.all(color: _healthAccent, width: 1.5)
                                  : null),
                        ),
                        child: Center(
                          child: done
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : Text('$d',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isToday
                                          ? _healthAccent
                                          : AppColors.textSecondary,
                                      fontWeight: isToday
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }),
    );
  }

  Widget _buildPeriodPhaseBar() {
    final cycle = _currentCycleLength;
    final periodDays = _currentPeriodDays.clamp(1, 12);
    final follEnd = (cycle * 0.46).round().clamp(periodDays + 2, cycle - 6);
    final ovEnd = (follEnd + 3).clamp(follEnd + 1, cycle - 3);
    final follDays = follEnd - periodDays;
    final ovDays = ovEnd - follEnd;
    final lutealDays = cycle - ovEnd;
    final currentDay = _todayCycleDay;

    final phases = [
      (label: '月经期', start: 1, flex: periodDays, color: _healthAccent),
      (
        label: '卵泡期',
        start: periodDays + 1,
        flex: follDays,
        color: _healthAccent.withValues(alpha: 0.45)
      ),
      (
        label: '排卵期',
        start: follEnd + 1,
        flex: ovDays,
        color: _healthAccent.withValues(alpha: 0.28)
      ),
      (
        label: '黄体期',
        start: ovEnd + 1,
        flex: lutealDays,
        color: _healthAccent.withValues(alpha: 0.15)
      ),
    ];

    int activeIdx = -1;
    if (currentDay > 0) {
      if (currentDay <= periodDays) {
        activeIdx = 0;
      } else if (currentDay <= follEnd) {
        activeIdx = 1;
      } else if (currentDay <= ovEnd) {
        activeIdx = 2;
      } else {
        activeIdx = 3;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 相位标签行：激活阶段用小矩形块包裹
        Row(
          children: List.generate(phases.length, (i) {
            final p = phases[i];
            final isActive = i == activeIdx;
            return Expanded(
              flex: p.flex,
              child: isActive
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _healthAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text(
                      p.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
            );
          }),
        ),
        const SizedBox(height: 6),
        // 色条 + 当前位置小长方形指示块
        Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: List.generate(phases.length, (i) {
                final p = phases[i];
                final isActive = i == activeIdx;
                return Expanded(
                  flex: p.flex,
                  child: Container(
                    height: 5,
                    margin:
                        EdgeInsets.only(right: i < phases.length - 1 ? 2 : 0),
                    decoration: BoxDecoration(
                      color: activeIdx == -1
                          ? p.color
                          : (isActive ? _healthAccent : _healthAccentLight),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                );
              }),
            ),
            if (currentDay > 0)
              Positioned.fill(
                child: LayoutBuilder(builder: (_, c) {
                  final progress = (currentDay - 1) / math.max(cycle - 1, 1);
                  final x =
                      (progress * c.maxWidth - 2.5).clamp(0.0, c.maxWidth - 5);
                  return Stack(children: [
                    Positioned(
                      left: x,
                      top: -3,
                      child: Container(
                        width: 5,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: _healthAccent, width: 1.5),
                        ),
                      ),
                    ),
                  ]);
                }),
              ),
          ],
        ),
        if (currentDay > 0) ...[
          const SizedBox(height: 6),
          Text(
            '第 $currentDay 天 · 共 $cycle 天',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 健康页由三块组成：健身打卡、生理期、体重记录，全部使用本地状态驱动。
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          // 页面标题栏。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('健康',
                  style: TextStyle(
                    fontFamily: 'XinDiXiaWuCha',
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  )),
              GestureDetector(
                onTap: _showModuleSettings,
                child: const Icon(Icons.tune,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 健身打卡 ──
          if (_fitnessVisible) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Text('健身',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleFitnessView,
                    child: Row(
                      children: [
                        Icon(
                          _showMonthView
                              ? Icons.view_week_outlined
                              : Icons.calendar_view_month_outlined,
                          size: 14,
                          color: _healthAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(_showMonthView ? '周视图' : '月视图',
                            style: const TextStyle(
                                fontSize: 11, color: _healthAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Card(
              child: GestureDetector(
                onTap: _handleFitnessCardBlankTap,
                behavior: HitTestBehavior.translucent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('本月运动 $_totalDays 天',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _healthAccent,
                            )),
                        const Spacer(),
                        Text('共 ${_formatMinutes(_totalMinutes)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 周条或月网格。
                    if (!_showMonthView) ...[
                      // 周视图：展示截至今天的近 7 天。
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _recent7Dates.map((date) {
                          final log = HealthStore.fitnessRecordForDate(date);
                          final isToday = DateUtils.isSameDay(date, _todayDate);
                          final done = log != null;
                          final isEditing = _showCheckin &&
                              DateUtils.isSameDay(date, _checkinDate);
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _openCheckinForDate(date),
                              onDoubleTap: done
                                  ? () => _cancelCheckinForDate(date)
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                children: [
                                  Text(_weekLabel(date),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: done
                                          ? _healthAccent
                                          : AppColors.bgTab,
                                      border: isEditing
                                          ? Border.all(
                                              color: _healthAccent, width: 1.5)
                                          : (isToday && !done
                                              ? Border.all(
                                                  color: _healthAccent,
                                                  width: 1.5)
                                              : null),
                                    ),
                                    child: Center(
                                      child: done
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 14)
                                          : Text('${date.day}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary)),
                                    ),
                                  ),
                                  if (done) ...[
                                    const SizedBox(height: 3),
                                    Text(log.type,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _healthAccent,
                                            fontWeight: FontWeight.w500)),
                                    Text(_formatMinutes(log.minutes),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      // 月视图：完整展示当月 30 天打卡情况，可点击切换完成状态。
                      Row(
                        children: ['日', '一', '二', '三', '四', '五', '六']
                            .map((w) => Expanded(
                                  child: Center(
                                    child: Text(w,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 2),
                      _buildMonthGrid(),
                    ],

                    // 打卡面板：选择运动类型和时长，确认后写入 _monthLog。
                    if (_showCheckin) ...[
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 10),
                      Text('${_checkinDate.month}月${_checkinDate.day}日运动记录',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _fitnessTypes.map((t) {
                          final sel = t == _selFitness;
                          return GestureDetector(
                            onTap: () => setState(() => _selFitness = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: sel ? _healthAccent : AppColors.bgTab,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textSecondary)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('时长',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _healthAccent,
                                thumbColor: _healthAccent,
                                inactiveTrackColor: AppColors.bgTab,
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                              ),
                              child: Slider(
                                value: _hours,
                                min: 0,
                                max: 3,
                                divisions: 12,
                                onChanged: (v) => setState(() => _hours = v),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(_formatDuration(_hours),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          HealthStore.saveFitnessRecord(
                            date: _checkinDate,
                            type: _selFitness,
                            minutes: (_hours * 60).round(),
                          );
                          _showCheckin = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _healthAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                                '确认 · $_selFitness ${_formatDuration(_hours)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 生理期 ──
          if (_periodVisible) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Text('生理期',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(
                        () => _showPeriodHistory = !_showPeriodHistory),
                    child: Row(
                      children: [
                        const Icon(Icons.history,
                            size: 14, color: _healthAccent),
                        const SizedBox(width: 3),
                        Text(_showPeriodHistory ? '收起' : '历史',
                            style: const TextStyle(
                                fontSize: 11, color: _healthAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Card(
              child: GestureDetector(
                onTap: () {
                  if (_showPeriodHistory) {
                    setState(() => _showPeriodHistory = false);
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头部：周期天数 + 当前阶段徽标
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _periodStatusText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _healthAccent,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_currentPhaseName != '--')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: _healthAccentLight,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _currentPhaseName,
                              style: const TextStyle(
                                  fontSize: 11, color: _healthAccent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 四阶段进度条（含标签 + 指示点 + 刻度）
                    _buildPeriodPhaseBar(),
                    const SizedBox(height: 10),
                    // 历史列表 或 开始/结束/下次 三格
                    if (_showPeriodHistory)
                      GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: _PeriodHistory(
                          records: _safePeriodRecords,
                          onSave: _savePeriodRecord,
                          onDelete: _deletePeriodRecord,
                          onClose: () =>
                              setState(() => _showPeriodHistory = false),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _editCurrentPeriodDate(editingStart: true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: _healthAccentLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(children: [
                                  const Text('开始',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 3),
                                  Text(_currentPeriodStartText,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _healthAccent,
                                          fontWeight: FontWeight.w500)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _editCurrentPeriodDate(editingStart: false),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: AppColors.bgTab,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(children: [
                                  const Text('结束',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 3),
                                  Text(_currentPeriodEndText,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _healthAccent,
                                          fontWeight: FontWeight.w500)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.bgTab,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(children: [
                                const Text('下次',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 3),
                                Text(_nextPeriodStartText,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: _healthAccent,
                                        fontWeight: FontWeight.w500)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 体重记录 ──
          if (_weightVisible) const _WeightCard(),
          if (_weightVisible) const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// 生理期历史记录。
class _PeriodHistory extends StatefulWidget {
  final List<_PeriodRecord>? records;
  final void Function({
    int? id,
    required String start,
    required String end,
    required int cycle,
  }) onSave;
  final ValueChanged<int> onDelete;
  final VoidCallback onClose;

  const _PeriodHistory({
    required this.records,
    required this.onSave,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<_PeriodHistory> createState() => _PeriodHistoryState();
}

class _PeriodHistoryState extends State<_PeriodHistory> {
  Future<void> _startAdd() => _openEditor();

  Future<void> _startEdit(_PeriodRecord record) => _openEditor(record: record);

  Future<void> _openEditor({_PeriodRecord? record}) async {
    final result = await showGeneralDialog<_PeriodRecordEditResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭生理期记录编辑',
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => _PeriodRecordEditor(record: record),
      transitionBuilder: (dialogContext, animation, _, child) {
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
                  padding: const EdgeInsets.fromLTRB(18, 170, 18, 20),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (result == null) return;
    if (!mounted) return;
    widget.onSave(
      id: record?.id,
      start: _formatPeriodDate(result.start),
      end: _formatPeriodDate(result.end),
      cycle: result.cycle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records ?? const <_PeriodRecord>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('历史记录',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: _startAdd,
              child: const Row(
                children: [
                  Icon(Icons.add, size: 14, color: _healthAccent),
                  SizedBox(width: 3),
                  Text('新增',
                      style: TextStyle(fontSize: 11, color: _healthAccent)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: records.isEmpty
              ? 0
              : (records.length > 3 ? 168 : records.length * 56.0),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            physics: records.length > 3
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: records.length,
            itemBuilder: (context, i) {
              final p = records[i];
              return Dismissible(
                key: ValueKey(p.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  HapticFeedback.mediumImpact();
                  widget.onDelete(p.id);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: _healthAccent.withValues(alpha: 0.10),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: _healthAccent),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    _startEdit(p);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i < records.length - 1
                          ? const Border(
                              bottom: BorderSide(
                                  color: AppColors.border, width: 0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _healthAccent),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.start} → ${p.end}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary)),
                              Text('${p.days}天 · 周期${p.cycle}天',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 14, color: AppColors.border),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        GestureDetector(
          onTap: widget.onClose,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('收起',
                  style: TextStyle(fontSize: 13, color: _healthAccent)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodRecordEditResult {
  final DateTime start;
  final DateTime end;
  final int cycle;
  const _PeriodRecordEditResult({
    required this.start,
    required this.end,
    required this.cycle,
  });
}

class _PeriodRecordEditor extends StatefulWidget {
  final _PeriodRecord? record;
  const _PeriodRecordEditor({this.record});

  @override
  State<_PeriodRecordEditor> createState() => _PeriodRecordEditorState();
}

class _PeriodRecordEditorState extends State<_PeriodRecordEditor> {
  late DateTime _startDate;
  late DateTime _endDate;
  late final TextEditingController _cycleCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final today = DateTime.now();
    _startDate = _parsePeriodDate(record?.start ?? '') ??
        DateTime(today.year, today.month, today.day);
    _endDate = _parsePeriodDate(record?.end ?? '') ??
        _startDate.add(const Duration(days: 5));
    _cycleCtrl = TextEditingController(text: '${record?.cycle ?? 28}');
  }

  @override
  void dispose() {
    _cycleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final cycle = int.tryParse(_cycleCtrl.text.trim());
    if (cycle == null || cycle < 15 || cycle > 60) {
      setState(() => _error = '周期请填写 15-60 之间的天数');
      return;
    }
    Navigator.pop(
      context,
      _PeriodRecordEditResult(start: _startDate, end: _endDate, cycle: cycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(editing ? '修改生理期' : '添加生理期',
              style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PeriodDateField(
                  label: '开始',
                  value: _startDate,
                  onChanged: (value) => setState(() {
                    final delta = value.difference(_startDate);
                    _startDate = value;
                    final shifted = _endDate.add(delta);
                    _endDate = shifted.isBefore(_startDate) ? _startDate : shifted;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PeriodDateField(
                  label: '结束',
                  value: _endDate,
                  onChanged: (value) => setState(() {
                    _endDate = value.isBefore(_startDate) ? _startDate : value;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PeriodTextField(ctrl: _cycleCtrl, hint: '周期 28'),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: const TextStyle(fontSize: 11, color: AppColors.holiday)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgTab,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('取消',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _healthAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('保存',
                          style: TextStyle(fontSize: 13, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _PeriodDateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭日期选择',
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: Center(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _PeriodDateWheelSheet(initial: value),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(_formatPeriodDate(value),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _PeriodDateWheelSheet extends StatefulWidget {
  final DateTime initial;
  const _PeriodDateWheelSheet({required this.initial});

  @override
  State<_PeriodDateWheelSheet> createState() => _PeriodDateWheelSheetState();
}

class _PeriodDateWheelSheetState extends State<_PeriodDateWheelSheet> {
  late final List<int> _years;
  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    final nowYear = DateTime.now().year;
    _years = [for (var y = nowYear - 6; y <= nowYear + 2; y++) y];
    _year = widget.initial.year.clamp(_years.first, _years.last).toInt();
    _month = widget.initial.month;
    _day = widget.initial.day;
  }

  void _normalizeDay() {
    final maxDay = DateUtils.getDaysInMonth(_year, _month);
    if (_day > maxDay) _day = maxDay;
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = DateUtils.getDaysInMonth(_year, _month);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: math.min(280.0, MediaQuery.of(context).size.height * 0.42),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Text('选择日期',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(context, DateTime(_year, _month, _day)),
                      child: const Text('完成',
                          style: TextStyle(
                              fontSize: 13,
                              color: _healthAccent,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 224,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController: FixedExtentScrollController(
                            initialItem: _years
                                .indexOf(_year)
                                .clamp(0, _years.length - 1)
                                .toInt()),
                        onSelectedItemChanged: (index) => setState(() {
                          _year = _years[index];
                          _normalizeDay();
                        }),
                        children: _years
                            .map((year) => Center(child: Text('$year年')))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController: FixedExtentScrollController(
                            initialItem: _month - 1),
                        onSelectedItemChanged: (index) => setState(() {
                          _month = index + 1;
                          _normalizeDay();
                        }),
                        children: List.generate(
                          12,
                          (i) => Center(child: Text('${i + 1}月')),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController:
                            FixedExtentScrollController(initialItem: _day - 1),
                        onSelectedItemChanged: (index) =>
                            setState(() => _day = index + 1),
                        children: List.generate(
                          maxDay,
                          (i) => Center(child: Text('${i + 1}日')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _PeriodTextField({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _healthAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
    );
  }
}

// 体重卡片。
class _WeightPoint {
  final int day;
  final double weight;
  final DateTime? date;
  const _WeightPoint(this.day, this.weight, {this.date});
}

class _WeightCard extends StatefulWidget {
  const _WeightCard();

  @override
  State<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<_WeightCard> {
  int _selectedDay = 1;
  final _scrollCtrl = ScrollController();
  bool? _didInitialScroll;
  bool? _showWeightMonthView;

  @override
  void initState() {
    super.initState();
    _selectedDay = _todayDay;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  DateTime get _todayDate => appToday;
  int get _todayDay => _todayDate.day;
  DateTime get _currentMonth => DateTime(_todayDate.year, _todayDate.month, 1);

  double get _todayWeight => _weightForDate(_todayDate);
  int get _visibleWeightStartDay => math.max(1, _todayDay - 6);
  int get _visibleSelectedDay =>
      _selectedDay < _visibleWeightStartDay || _selectedDay > _todayDay
          ? _todayDay
          : _selectedDay;
  bool get _isWeightMonthView => _showWeightMonthView ?? false;

  double _weightForDate(DateTime date) => WeightStore.weightForDate(date);

  double _weightForDay(int day) =>
      _weightForDate(DateTime(_currentMonth.year, _currentMonth.month, day));

  Future<void> _editWeightDate(DateTime date) async {
    final value = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭体重填写框',
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => _WeightEditPopup(
        label: '${date.month}月${date.day}日',
        initialWeight: _weightForDate(date),
      ),
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  18,
                  150,
                  18,
                  MediaQuery.of(dialogContext).viewInsets.bottom + 20,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (value == null) return;
    if (!mounted) return;
    setState(() {
      if (date.year == _currentMonth.year &&
          date.month == _currentMonth.month) {
        _selectedDay = date.day;
      }
      WeightStore.setWeight(date, value);
    });
  }

  Future<void> _editWeight(int day) {
    return _editWeightDate(
        DateTime(_currentMonth.year, _currentMonth.month, day));
  }

  List<_WeightPoint> get _chartPoints {
    return List.generate(
      _todayDay - _visibleWeightStartDay + 1,
      (i) {
        final day = _visibleWeightStartDay + i;
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        return _WeightPoint(day, _weightForDate(date), date: date);
      },
    );
  }

  List<_WeightPoint> get _ninetyDayPoints {
    return List.generate(90, (i) {
      final daysAgo = 89 - i;
      final date = _todayDate.subtract(Duration(days: daysAgo));
      return _WeightPoint(i + 1, _weightForDate(date), date: date);
    });
  }

  String get _recentChangeText {
    final first = _weightForDay(_visibleWeightStartDay);
    final current = _weightForDay(_visibleSelectedDay);
    final diff = current - first;
    if (diff.abs() < 0.05) return '近7天体重基本持平';
    final label = diff < 0 ? '减重' : '增重';
    return '近7天$label ${diff.abs().toStringAsFixed(1)} kg';
  }

  String get _ninetyDayChangeText {
    final points = _ninetyDayPoints;
    final diff = points.last.weight - points.first.weight;
    if (diff.abs() < 0.05) return '近90天体重基本持平';
    final label = diff < 0 ? '减重' : '增重';
    return '近90天$label ${diff.abs().toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final points = _chartPoints;
    final ninetyDayPoints = _ninetyDayPoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分区标题（卡片外）
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Text('体重',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.bgTab,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    _WeightViewChip(
                      label: '7天',
                      selected: !_isWeightMonthView,
                      onTap: () => setState(() => _showWeightMonthView = false),
                    ),
                    _WeightViewChip(
                      label: '月视图',
                      selected: _isWeightMonthView,
                      onTap: () => setState(() => _showWeightMonthView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 0),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _editWeight(_todayDay),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_todayWeight.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _healthAccent,
                        )),
                    const SizedBox(width: 3),
                    const Text('kg',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined,
                        size: 13, color: AppColors.textSecondary),
                  ],
                ),
              ),
              Text('今日 · ${_todayDate.month}月$_todayDay日',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              if (_isWeightMonthView)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final segment =
                            chartWidth / math.max(ninetyDayPoints.length, 1);
                        final index = (details.localPosition.dx / segment)
                            .floor()
                            .clamp(0, ninetyDayPoints.length - 1)
                            .toInt();
                        final date = ninetyDayPoints[index].date ?? _todayDate;
                        _editWeightDate(date);
                      },
                      child: SizedBox(
                        height: 132,
                        width: chartWidth,
                        child: CustomPaint(
                          painter:
                              _WeightNinetyDayPainter(points: ninetyDayPoints),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints.maxWidth;
                    if (_didInitialScroll != true) {
                      _didInitialScroll = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_scrollCtrl.hasClients) return;
                        _scrollCtrl
                            .jumpTo(_scrollCtrl.position.maxScrollExtent);
                      });
                    }
                    return SingleChildScrollView(
                      controller: _scrollCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final segment =
                              chartWidth / math.max(points.length - 1, 1);
                          final index = (details.localPosition.dx / segment)
                              .round()
                              .clamp(0, points.length - 1)
                              .toInt();
                          final day = points[index].day;
                          setState(() => _selectedDay = day);
                          _editWeight(day);
                        },
                        child: SizedBox(
                          width: chartWidth,
                          height: 132,
                          child: CustomPaint(
                            painter: _WeightChartPainter(
                              points: points,
                              selectedDay: _visibleSelectedDay,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_isWeightMonthView
                              ? ninetyDayPoints.last.weight <=
                                  ninetyDayPoints.first.weight
                              : _weightForDay(_visibleSelectedDay) <=
                                  _weightForDay(_visibleWeightStartDay))
                          ? Icons.trending_down
                          : Icons.trending_up,
                      size: 16,
                      color: _healthAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                        _isWeightMonthView
                            ? _ninetyDayChangeText
                            : _recentChangeText,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightEditPopup extends StatefulWidget {
  final String label;
  final double initialWeight;
  const _WeightEditPopup({
    required this.label,
    required this.initialWeight,
  });

  @override
  State<_WeightEditPopup> createState() => _WeightEditPopupState();
}

class _WeightEditPopupState extends State<_WeightEditPopup> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        TextEditingController(text: widget.initialWeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = double.tryParse(_ctrl.text.trim());
    if (parsed == null || parsed < 30 || parsed > 150) return;
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('记录 ${widget.label}体重',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              suffixText: 'kg',
              filled: true,
              fillColor: AppColors.bgPage,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _healthAccent),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _healthAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _WeightViewChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _WeightViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? _healthAccent : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    );
  }
}

class _WeightNinetyDayPainter extends CustomPainter {
  final List<_WeightPoint> points;
  const _WeightNinetyDayPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final weights = points.map((point) => point.weight).toList();
    final min = weights.reduce(math.min);
    final max = weights.reduce(math.max);
    final range = (max - min).abs() < 0.01 ? 0.5 : max - min;
    final chartHeight = size.height - 26;
    final barGap = size.width / points.length;
    final barWidth = math.max(1.6, barGap * 0.52);
    final bottomY = chartHeight + 4;

    final gridPaint = Paint()
      ..color = AppColors.border.withAlpha(110)
      ..strokeWidth = 0.7;
    canvas.drawLine(const Offset(0, 8), Offset(size.width, 8), gridPaint);
    canvas.drawLine(Offset(0, chartHeight / 2 + 6),
        Offset(size.width, chartHeight / 2 + 6), gridPaint);
    canvas.drawLine(Offset(0, bottomY), Offset(size.width, bottomY), gridPaint);

    for (int i = 0; i < points.length; i++) {
      final normalized = (points[i].weight - min) / range;
      final barHeight = 8 + normalized * (chartHeight - 18);
      final x = i * barGap + (barGap - barWidth) / 2;
      final top = bottomY - barHeight;
      final paint = Paint()
        ..color = _healthAccent.withAlpha((120 + normalized * 95).round())
        ..style = PaintingStyle.fill;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, math.max(1.5, barHeight)),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, double x) {
      textPainter.text = TextSpan(
        text: text,
        style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
      );
      textPainter.layout();
      final dx = (x - textPainter.width / 2)
          .clamp(0.0, size.width - textPainter.width)
          .toDouble();
      textPainter.paint(
        canvas,
        Offset(dx, size.height - 15),
      );
    }

    label('90天前', 0);
    label('60天', size.width / 3);
    label('30天', size.width * 2 / 3);
    label('今天', size.width);

    textPainter.text = TextSpan(
      text: '${points.last.weight.toStringAsFixed(1)}kg',
      style: const TextStyle(
          fontSize: 10, color: _healthAccent, fontWeight: FontWeight.w600),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width, 0));
  }

  @override
  bool shouldRepaint(covariant _WeightNinetyDayPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

// 体重图表绘制器。
class _WeightChartPainter extends CustomPainter {
  final List<_WeightPoint> points;
  final int selectedDay;
  const _WeightChartPainter({
    required this.points,
    required this.selectedDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final weights = points.map((p) => p.weight).toList();
    final min = weights.reduce(math.min);
    final max = weights.reduce(math.max);
    final range = (max - min).abs() < 0.01 ? 0.5 : max - min;
    final chartHeight = size.height - 28;
    final step = size.width / math.max(points.length - 1, 1);
    final offsets = List.generate(points.length, (i) {
      final x = i * step;
      final y = chartHeight -
          ((points[i].weight - min) / range) * (chartHeight - 18) +
          4;
      return Offset(x, y);
    });

    final gridPaint = Paint()
      ..color = AppColors.border.withAlpha(120)
      ..strokeWidth = 0.6;
    for (int i = 0; i < 3; i++) {
      final y = 8 + i * (chartHeight - 8) / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = _healthAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < points.length; i++) {
      final selected = points[i].day == selectedDay;
      final dotPaint = Paint()
        ..color = selected ? _healthAccent : _healthAccent.withAlpha(210)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offsets[i], selected ? 5 : 3, dotPaint);
      if (selected) {
        textPainter.text = TextSpan(
          text: '${points[i].weight.toStringAsFixed(1)}kg',
          style: const TextStyle(fontSize: 9, color: _healthAccent),
        );
        textPainter.layout();
        textPainter.paint(canvas, offsets[i] + const Offset(-14, -20));
      }
      textPainter.text = TextSpan(
        text: '${points[i].day}日',
        style: TextStyle(
          fontSize: 7,
          color: selected ? _healthAccent : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(offsets[i].dx - textPainter.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedDay != selectedDay;
  }
}

// 卡片容器。
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    // 健康页统一卡片容器，保持边框、圆角和轻阴影一致。
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: child,
    );
  }
}
