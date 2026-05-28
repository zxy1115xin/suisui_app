import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../app_colors.dart';
import '../health_store.dart';
import '../storage_service.dart';
import '../weight_store.dart';

// 数据区。
const _fitnessTypes = ['跑步', '瑜伽', '力量', '骑行', '游泳', '其他'];
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

  bool _showMonthView = false;
  double _fitnessDragOffset = 0;

  int get _calStartDay =>
      DateTime(_todayDate.year, _todayDate.month, 1).weekday % 7;
  int get _calDays =>
      DateUtils.getDaysInMonth(_todayDate.year, _todayDate.month);
  int get _todayDay => _todayDate.day;

  // 本周日起的 7 天（周日在最左）
  List<DateTime> get _recent7Dates {
    final daysSinceSunday = _todayDate.weekday % 7;
    final sunday = _todayDate.subtract(Duration(days: daysSinceSunday));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

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
                                  if (!next) _showMonthView = false;
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
    setState(() {});
  }

  Future<void> _openCheckinForDate(DateTime date) async {
    final existingLog = HealthStore.fitnessRecordForDate(date);
    final result = await showGeneralDialog<({String type, int minutes})>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭运动记录',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _FitnessCheckinDialog(
        date: date,
        initialType: existingLog?.type,
        initialMinutes: existingLog?.minutes,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: Center(
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
        );
      },
    );
    if (result == null || !mounted) return;
    HealthStore.saveFitnessRecord(
      date: date,
      type: result.type,
      minutes: result.minutes,
    );
    setState(() {});
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
    if (_todayCycleDay <= 0) {
      final window = _currentPeriodWindow;
      if (window == null) return '暂无生理期预测';
      return '距离月经期还有 ${window.start.difference(_todayDate).inDays} 天';
    }
    final phaseName = _currentPhaseName;
    if (phaseName.isEmpty) return '暂无生理期数据';
    return '当前$phaseName的第$_currentPhaseDay天';
  }

  String get _currentPeriodStartText {
    final window = _currentPeriodWindow;
    if (window == null) return '--';
    return '${window.start.month}月${window.start.day}日';
  }

  /// 根据实际记录推算今天所在周期的起始日和周期长度。
  /// 周期长度优先取相邻两次记录的实际间隔，无下次记录则取上次间隔或存储值。
  ({DateTime cycleStart, int cycleLength})? get _activeCycleInfo {
    final records = _safePeriodRecords;
    if (records.isEmpty) return null;

    final today = _todayDate;
    final starts = records
        .map((r) => _parsePeriodDate(r.start))
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (starts.isEmpty) return null;

    // 找到最近一个 ≤ today 的记录起始日
    int foundIdx = -1;
    for (int i = starts.length - 1; i >= 0; i--) {
      if (!starts[i].isAfter(today)) {
        foundIdx = i;
        break;
      }
    }
    if (foundIdx < 0) return null;

    final base = starts[foundIdx];

    // 周期长度：优先用相邻两次记录的实际间距
    int cycleLen;
    if (foundIdx + 1 < starts.length) {
      cycleLen = starts[foundIdx + 1].difference(base).inDays.clamp(15, 60);
    } else if (foundIdx > 0) {
      cycleLen = base.difference(starts[foundIdx - 1]).inDays.clamp(15, 60);
    } else {
      cycleLen = math.max(records.first.cycle, 15);
    }

    // 如果今天已超出本次周期，按周期滚动到包含今天的预测周期
    var cycleStart = base;
    while (!today.isBefore(cycleStart.add(Duration(days: cycleLen)))) {
      cycleStart = cycleStart.add(Duration(days: cycleLen));
    }

    return (cycleStart: cycleStart, cycleLength: cycleLen);
  }

  int get _currentCycleLength => _activeCycleInfo?.cycleLength ?? 28;

  int get _currentPeriodDays {
    final sorted = _safePeriodRecords;
    return sorted.isEmpty ? 5 : math.max(sorted.first.days, 1);
  }

  int get _todayCycleDay {
    final info = _activeCycleInfo;
    if (info == null) return 0;
    final diff = _todayDate.difference(info.cycleStart).inDays;
    return (diff + 1).clamp(1, info.cycleLength);
  }

  int get _periodFollEnd {
    final cycle = _currentCycleLength;
    final periodDays = _currentPeriodDays.clamp(1, 12);
    // 月经期18% + 卵泡期29% = 47%
    return (cycle * 0.47).round().clamp(periodDays + 1, cycle - 2);
  }

  int get _periodOvEnd {
    final cycle = _currentCycleLength;
    // 月经期18% + 卵泡期29% + 排卵期4% = 51%
    return (cycle * 0.51).round().clamp(_periodFollEnd + 1, cycle - 1);
  }

  String get _currentPhaseName {
    final day = _todayCycleDay;
    if (day <= 0) return '';
    final periodDays = _currentPeriodDays.clamp(1, 12);
    if (day <= periodDays) return '月经期';
    if (day <= _periodFollEnd) return '卵泡期';
    if (day <= _periodOvEnd) return '排卵期';
    return '黄体期';
  }

  int get _currentPhaseDay {
    final day = _todayCycleDay;
    if (day <= 0) return 0;
    final periodDays = _currentPeriodDays.clamp(1, 12);
    final follEnd = _periodFollEnd;
    final ovEnd = _periodOvEnd;
    if (day <= periodDays) return day;
    if (day <= follEnd) return day - periodDays;
    if (day <= ovEnd) return day - follEnd;
    return day - ovEnd;
  }

  String get _prevPeriodStartText {
    final currentWindow = _currentPeriodWindow;
    if (currentWindow == null) return '--';
    // 查历史记录中当前期之前最近的一条，独立于本月的编辑
    for (final r in _safePeriodRecords) {
      final start = _parsePeriodDate(r.start);
      if (start != null && start.isBefore(currentWindow.start)) {
        return '${start.month}月${start.day}日';
      }
    }
    return '--';
  }

  String get _nextPeriodStartText {
    final window = _currentPeriodWindow;
    if (window == null) return '--';
    final next = window.start.add(Duration(days: _currentCycleLength));
    return '${next.month}月${next.day}日';
  }

  _PeriodRecord? get _prevPeriodRecord {
    final currentWindow = _currentPeriodWindow;
    if (currentWindow == null) return null;
    for (final r in _safePeriodRecords) {
      final start = _parsePeriodDate(r.start);
      if (start != null && start.isBefore(currentWindow.start)) return r;
    }
    return null;
  }

  Future<void> _editPeriodByRecord({
    _PeriodRecord? record,
    DateTime? defaultStart,
  }) async {
    final initStart = _parsePeriodDate(record?.start ?? '') ?? defaultStart ?? _todayDate;
    final initEnd = _parsePeriodDate(record?.end ?? '') ??
        initStart.add(const Duration(days: 5));
    final result = await showGeneralDialog<_PeriodRecordEditResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭生理期记录编辑',
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => _PeriodRecordEditor(
        record: record,
        initialStart: initStart,
        initialEnd: initEnd,
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
    if (result == null || !mounted) return;
    _savePeriodRecord(
      id: record?.id,
      start: _formatPeriodDate(result.start),
      end: _formatPeriodDate(result.end),
      cycle: result.cycle,
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
    final cells = <int?>[
      ...List<int?>.filled(_calStartDay, null),
      ...List.generate(_calDays, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    // 行高加大以容纳类型+时长标签
    const rowHeight = 74.0;
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
              final log = _monthLog[d];
              final done = log != null;
              final isToday = d == _todayDay;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _openCheckinForDate(date),
                  onDoubleTap: done ? () => _cancelCheckinForDate(date) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? _healthAccent : AppColors.bgTab,
                          border: (isToday && !done)
                              ? Border.all(color: _healthAccent, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: done
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : Text('$d',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                        ),
                      ),
                      if (done) ...[
                        const SizedBox(height: 3),
                        Text(log[0] as String,
                            style: const TextStyle(
                                fontSize: 11,
                                color: _healthAccent,
                                fontWeight: FontWeight.w500)),
                        Text(_formatMinutes(log[1] as int),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ] else ...[
                        // 占位保持高度一致
                        const SizedBox(height: 3),
                        const Text('·',
                            style: TextStyle(
                                fontSize: 11, color: Colors.transparent)),
                        const Text('·',
                            style: TextStyle(
                                fontSize: 11, color: Colors.transparent)),
                      ],
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
    final follEnd = _periodFollEnd;
    final ovEnd = _periodOvEnd;
    final currentDay = _todayCycleDay;
    final phaseName = _currentPhaseName;
    final phaseDay = _currentPhaseDay;

    // 固定比例 18/29/4/50，视觉上不随周期变化
    const barFlexes = [18, 29, 4, 50];
    const barTotal = 101;
    const phaseLabels = ['月经期', '卵泡期', '排卵期', '黄体期'];
    const phasePoems = [
      '月落时分，静养身心',
      '春意渐生，元气回升',
      '花开一瞬，生命待启',
      '潮汐微澜，情绪轻漾',
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
        // 标签行：同字号，居中于各自分段正上方，宽度不足时允许溢出相邻区域
        SizedBox(
          height: 16,
          child: LayoutBuilder(builder: (_, c) {
            double cumX = 0;
            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(phaseLabels.length, (i) {
                final segW = c.maxWidth * barFlexes[i] / barTotal;
                final centerX = cumX + segW / 2;
                cumX += segW;
                final isActive = i == activeIdx;
                return Positioned(
                  top: 0,
                  left: centerX,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Text(
                      phaseLabels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? _healthAccent : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
        const SizedBox(height: 4),
        // 色条：固定 18/29/4/50 比例，激活段高 10px、实色；非激活段高 5px、极淡
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(phaseLabels.length, (i) {
                  final isActive = i == activeIdx;
                  return Expanded(
                    flex: barFlexes[i],
                    child: Container(
                      height: isActive ? 10 : 5,
                      margin: EdgeInsets.only(
                          right: i < phaseLabels.length - 1 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _healthAccent
                            : _healthAccent.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(isActive ? 5 : 2.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (currentDay > 0 && activeIdx >= 0)
              Positioned.fill(
                child: LayoutBuilder(builder: (_, c) {
                  // 各期天数
                  final phaseTotals = [
                    periodDays,
                    math.max(follEnd - periodDays, 1),
                    math.max(ovEnd - follEnd, 1),
                    math.max(cycle - ovEnd, 1),
                  ];
                  // 各段起始 x 和可见宽度（段之间有 4px 间隙）
                  const segGap = 4.0;
                  var cumX = 0.0;
                  final segStarts = <double>[];
                  final segVisibleW = <double>[];
                  for (int i = 0; i < barFlexes.length; i++) {
                    final allocW = barFlexes[i] / barTotal * c.maxWidth;
                    segStarts.add(cumX);
                    segVisibleW.add(
                        allocW - (i < barFlexes.length - 1 ? segGap : 0.0));
                    cumX += allocW;
                  }
                  // 当前期内进度 (0..1)
                  final phaseProgress =
                      phaseDay / math.max(phaseTotals[activeIdx], 1);
                  // 圆点中心 = 段起始 + 期内进度 × 段可见宽度
                  const dotSize = 12.0;
                  final dotCenter = segStarts[activeIdx] +
                      phaseProgress * segVisibleW[activeIdx];
                  final x = (dotCenter - dotSize / 2)
                      .clamp(0.0, c.maxWidth - dotSize);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: x,
                        top: (10 - dotSize) / 2,
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: _healthAccent, width: 2.5),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 0,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: _healthAccent.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
        // 胶囊标签：右端靠近 today 标记，左端不超出卡片
        if (currentDay > 0 && phaseName.isNotEmpty) ...[
          const SizedBox(height: 8),
          LayoutBuilder(builder: (_, c) {
            final phaseTotals = [
              periodDays,
              math.max(follEnd - periodDays, 1),
              math.max(ovEnd - follEnd, 1),
              math.max(cycle - ovEnd, 1),
            ];
            const segGap = 4.0;
            var cumX = 0.0;
            final segStarts = <double>[];
            final segVisibleW = <double>[];
            for (int i = 0; i < barFlexes.length; i++) {
              final allocW = barFlexes[i] / barTotal * c.maxWidth;
              segStarts.add(cumX);
              segVisibleW.add(
                  allocW - (i < barFlexes.length - 1 ? segGap : 0.0));
              cumX += allocW;
            }
            final phaseProgress =
                phaseDay / math.max(phaseTotals[activeIdx], 1);
            final anchorX =
                segStarts[activeIdx] + phaseProgress * segVisibleW[activeIdx];
            const pillW = 140.0;
            final left = (anchorX - pillW).clamp(0.0, c.maxWidth - pillW);
            return SizedBox(
              height: 22,
              child: Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    child: Container(
                      width: pillW,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _healthAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        phasePoems[activeIdx],
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                            fontSize: 11, color: _healthAccent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 健康页由三块组成：健身打卡、生理期、体重记录，全部使用本地状态驱动。
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          // 页面标题栏。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('健康',
                  style: TextStyle(
                    fontFamily: 'XinDiXiaWuCha',
                    fontSize: 24,
                    color: AppColors.textPrimary,
                  )),
              GestureDetector(
                onTap: _showModuleSettings,
                child: const Icon(Icons.tune,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── 健身打卡 ──
          if (_fitnessVisible) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Text('健身',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.bgTab,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WeightViewChip(
                          label: '7天',
                          selected: !_showMonthView,
                          onTap: () => setState(() => _showMonthView = false),
                        ),
                        _WeightViewChip(
                          label: '月视图',
                          selected: _showMonthView,
                          onTap: () => setState(() => _showMonthView = true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Card(
              child: GestureDetector(
                onVerticalDragStart: (_) => _fitnessDragOffset = 0,
                onVerticalDragUpdate: (details) {
                  _fitnessDragOffset += details.primaryDelta ?? 0;
                },
                onVerticalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  final disp = _fitnessDragOffset;
                  _fitnessDragOffset = 0;
                  final expand = v > 500 || (v > 150 && disp > 60);
                  final collapse = v < -500 || (v < -150 && disp < -60);
                  if (expand && !_showMonthView) {
                    HapticFeedback.lightImpact();
                    setState(() => _showMonthView = true);
                  } else if (collapse && _showMonthView) {
                    HapticFeedback.lightImpact();
                    setState(() => _showMonthView = false);
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('本月运动 $_totalDays 天',
                            style: const TextStyle(
                              fontSize: 15,
                              color: _healthAccent,
                            )),
                        const Spacer(),
                        Text('共 ${_formatMinutes(_totalMinutes)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 周条或月网格。
                    if (!_showMonthView) ...[
                      // 周视图：本周（周日-周六），未来日期灰显不可点。
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _recent7Dates.map((date) {
                          final isFuture = date.isAfter(_todayDate);
                          final log = isFuture ? null : HealthStore.fitnessRecordForDate(date);
                          final isToday = DateUtils.isSameDay(date, _todayDate);
                          final done = log != null;
                          return Expanded(
                            child: GestureDetector(
                              onTap: isFuture ? null : () => _openCheckinForDate(date),
                              onDoubleTap: done ? () => _cancelCheckinForDate(date) : null,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                children: [
                                  Text(_weekLabel(date),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isFuture
                                              ? AppColors.border
                                              : (isToday || done)
                                                  ? _healthAccent
                                                  : AppColors.textSecondary)),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: done ? _healthAccent : AppColors.bgTab,
                                      border: (!isFuture && isToday && !done)
                                          ? Border.all(color: _healthAccent, width: 1.5)
                                          : null,
                                    ),
                                    child: Center(
                                      child: done
                                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                                          : Text('${date.day}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: isFuture
                                                      ? AppColors.border
                                                      : AppColors.textSecondary)),
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
                            .asMap()
                            .entries
                            .map((e) => Expanded(
                                  child: Center(
                                    child: Text(e.value,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: (e.key == 0 || e.key == 6)
                                                ? const Color(0xFFD8635F)
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      _buildMonthGrid(),
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
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(
                        () => _showPeriodHistory = !_showPeriodHistory),
                    child: Row(
                      children: [
                        const Icon(Icons.history,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(_showPeriodHistory ? '收起' : '历史',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
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
                    Text(
                      _periodStatusText,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _healthAccent,
                      ),
                    ),
                    const SizedBox(height: 18),
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
                          for (final (label, dateText, onTap) in [
                            (
                              '上月',
                              _prevPeriodStartText,
                              () => _editPeriodByRecord(
                                record: _prevPeriodRecord,
                                defaultStart: _prevPeriodRecord == null
                                    ? _currentPeriodWindow?.start.subtract(
                                        Duration(days: _currentCycleLength))
                                    : null,
                              ),
                            ),
                            (
                              '本月',
                              _currentPeriodStartText,
                              () => _editPeriodByRecord(
                                record: _currentPeriodRecord,
                                defaultStart: _currentPeriodWindow?.start,
                              ),
                            ),
                            ('下月', _nextPeriodStartText, null),
                          ]) ...[
                            if (label != '上月') const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onTap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgTab,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(label,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                      Text(dateText,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                  onTap: () => _startEdit(p),
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
  final DateTime? initialStart;
  final DateTime? initialEnd;
  const _PeriodRecordEditor({this.record, this.initialStart, this.initialEnd});

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
        widget.initialStart ??
        DateTime(today.year, today.month, today.day);
    _endDate = _parsePeriodDate(record?.end ?? '') ??
        widget.initialEnd ??
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

  // 本周变化（带符号）
  String get _weekChangeStat {
    final first = _chartPoints
        .firstWhere((p) => p.weight > 0,
            orElse: () => _WeightPoint(0, 0))
        .weight;
    final last = _chartPoints
        .lastWhere((p) => p.weight > 0,
            orElse: () => _WeightPoint(0, 0))
        .weight;
    if (first == 0 || last == 0) return '--';
    final diff = last - first;
    if (diff.abs() < 0.05) return '持平';
    return '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg';
  }

  // 近90天变化（带符号）
  String get _monthChangeStat {
    final pts = _ninetyDayPoints.where((p) => p.weight > 0).toList();
    if (pts.length < 2) return '--';
    final diff = pts.last.weight - pts.first.weight;
    if (diff.abs() < 0.05) return '持平';
    return '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg';
  }

  // 本周均值
  String get _weekAvgStat {
    final pts = _chartPoints.where((p) => p.weight > 0).toList();
    if (pts.isEmpty) return '--';
    final avg = pts.map((p) => p.weight).reduce((a, b) => a + b) / pts.length;
    return '${avg.toStringAsFixed(1)} kg';
  }

  // 近90天均值
  String get _monthAvgStat {
    final pts = _ninetyDayPoints.where((p) => p.weight > 0).toList();
    if (pts.isEmpty) return '--';
    final avg = pts.map((p) => p.weight).reduce((a, b) => a + b) / pts.length;
    return '${avg.toStringAsFixed(1)} kg';
  }

  // 本周最低
  String get _weekMinStat {
    final pts = _chartPoints.where((p) => p.weight > 0).toList();
    if (pts.isEmpty) return '--';
    final min = pts.map((p) => p.weight).reduce(math.min);
    return '${min.toStringAsFixed(1)} kg';
  }

  // 近90天最低
  String get _monthMinStat {
    final pts = _ninetyDayPoints.where((p) => p.weight > 0).toList();
    if (pts.isEmpty) return '--';
    final min = pts.map((p) => p.weight).reduce(math.min);
    return '${min.toStringAsFixed(1)} kg';
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _editWeight(_todayDay),
                child: Text(
                  '今日体重  ${_todayWeight > 0 ? _todayWeight.toStringAsFixed(1) : '--'} kg',
                  style: const TextStyle(
                    fontSize: 15,
                    color: _healthAccent,
                  ),
                ),
              ),
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
              const SizedBox(height: 12),
              // 三列统计行：本周/本月 · 均值 · 最低
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: AppColors.border, width: 1)),
                ),
                padding: const EdgeInsets.only(top: 12),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _WeightStat(
                        label: _isWeightMonthView ? '本月' : '本周',
                        value: _isWeightMonthView
                            ? _monthChangeStat
                            : _weekChangeStat,
                      ),
                      const VerticalDivider(
                          color: AppColors.border, width: 1, thickness: 1),
                      _WeightStat(
                        label: '均值',
                        value: _isWeightMonthView
                            ? _monthAvgStat
                            : _weekAvgStat,
                      ),
                      const VerticalDivider(
                          color: AppColors.border, width: 1, thickness: 1),
                      _WeightStat(
                        label: '最低',
                        value: _isWeightMonthView
                            ? _monthMinStat
                            : _weekMinStat,
                      ),
                    ],
                  ),
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
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
          fontSize: 11, color: _healthAccent, fontWeight: FontWeight.w600),
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
      final hasWeight = points[i].weight > 0;
      final dotPaint = Paint()
        ..color = selected ? _healthAccent : _healthAccent.withAlpha(210)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offsets[i], selected ? 5 : 3, dotPaint);

      if (hasWeight) {
        textPainter.text = TextSpan(
          text: points[i].weight.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 10,
            color: _healthAccent,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
        textPainter.layout();
        final lx = (offsets[i].dx - textPainter.width / 2)
            .clamp(0.0, size.width - textPainter.width);
        final ly = math.max(0.0, offsets[i].dy - textPainter.height - 4);
        textPainter.paint(canvas, Offset(lx, ly));
      }

      textPainter.text = TextSpan(
        text: '${points[i].day}日',
        style: TextStyle(
          fontSize: 10,
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

// 体重三列统计单元。
class _WeightStat extends StatelessWidget {
  final String label;
  final String value;
  const _WeightStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// 卡片容器。
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A4A3728), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

// 打卡弹窗（悬浮对话框，不展开卡片）。
class _FitnessCheckinDialog extends StatefulWidget {
  final DateTime date;
  final String? initialType;
  final int? initialMinutes;

  const _FitnessCheckinDialog({
    required this.date,
    this.initialType,
    this.initialMinutes,
  });

  @override
  State<_FitnessCheckinDialog> createState() => _FitnessCheckinDialogState();
}

class _FitnessCheckinDialogState extends State<_FitnessCheckinDialog> {
  late String _sel;
  late double _hours;

  @override
  void initState() {
    super.initState();
    _sel = widget.initialType ?? _fitnessTypes.first;
    _hours = widget.initialMinutes != null ? widget.initialMinutes! / 60 : 1.0;
  }

  String _fmt(double h) {
    if (h == 0) return '未记录';
    if (h < 1) return '${(h * 60).round()}分钟';
    if (h == h.truncate()) return '${h.toInt()}小时';
    return '${h.toStringAsFixed(1)}小时';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.date.month}月${widget.date.day}日运动记录',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            children: _fitnessTypes.asMap().entries.map((e) {
              final t = e.value;
              final sel = t == _sel;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sel = t),
                  child: Container(
                    margin: EdgeInsets.only(left: e.key == 0 ? 0 : 5),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _healthAccent : AppColors.bgTab,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(t,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                sel ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('时长',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _healthAccent,
                    thumbColor: _healthAccent,
                    inactiveTrackColor: AppColors.bgTab,
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
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
                child: Text(_fmt(_hours),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgTab,
                      borderRadius: BorderRadius.circular(12),
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
                  onTap: () => Navigator.pop(
                    context,
                    (type: _sel, minutes: (_hours * 60).round()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _healthAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('确认 · $_sel ${_fmt(_hours)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
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
