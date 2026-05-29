import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../important_date_store.dart';
import '../todo_store.dart';
import '../weight_store.dart';

DateTime get _today => appToday;

const _todoAccent = AppColors.brand;
const _todoAccentLight = AppColors.brandLight;
const _eventColor = AppColors.event;
const _eventColorLight = AppColors.eventLight;
const _anniversaryColor = AppColors.period;
const _anniversaryColorLight = AppColors.periodLight;

// 页面主体。
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  // 记录页目前使用本地内存数据，适合原型阶段快速验证交互。
  final _todoCtrl = TextEditingController();
  Timer? _todayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTodayRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _todayTimer?.cancel();
    _todoCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    setState(() {});
    _scheduleTodayRefresh();
  }

  void _scheduleTodayRefresh() {
    _todayTimer?.cancel();
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final tomorrowBeijing = DateTime(now.year, now.month, now.day + 1);
    final delay = tomorrowBeijing.difference(now) + const Duration(seconds: 1);
    _todayTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleTodayRefresh();
    });
  }

  void _addTodo(String text) {
    // 统一处理待办新增：过滤空输入、写入共享待办列表并清空输入框。
    if (text.trim().isEmpty) return;
    TodoStore.add(text);
    _todoCtrl.clear();
  }

  Future<T?> _showJournalPopup<T>(
    BuildContext context,
    Widget child, {
    double top = 96,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭填写框',
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
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    return SafeArea(
      child: ValueListenableBuilder<int>(
        valueListenable: ImportantDateStore.version,
        builder: (context, _, __) {
          // 重要事件在构建时按“未来 / 已发生”拆分，方便分别展示不同视觉状态。
          final futureEvents = ImportantDateStore.events
              .where((e) => !e.isPastFrom(today))
              .toList()
            ..sort((a, b) => a.dateValue.compareTo(b.dateValue));
          final pastEvents = ImportantDateStore.events
              .where((e) => e.isPastFrom(today))
              .toList()
            ..sort((a, b) => b.dateValue.compareTo(a.dateValue));
          final upcomingBirthdays = [...ImportantDateStore.birthdays]..sort(
              (a, b) => a
                  .daysUntilBirthdayFrom(today)
                  .compareTo(b.daysUntilBirthdayFrom(today)),
            );
          final upcomingAnniversaries = [...ImportantDateStore.anniversaries]
            ..sort(
              (a, b) => a
                  .daysUntilAnniversaryFrom(today)
                  .compareTo(b.daysUntilAnniversaryFrom(today)),
            );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              const Text('记录',
                  style: TextStyle(
                    fontFamily: 'XinDiXiaWuCha',
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 16),

              // ── 待办事项 ──
              _SectionHeader(
                title: '待办事项',
                actionColor: _todoAccent,
                onAdd: () => _showTodoSheet(context),
              ),
              _SectionCard(
                child: ValueListenableBuilder<List<TodoItem>>(
                  valueListenable: TodoStore.items,
                  builder: (context, todos, _) {
                    return _LimitedList(
                      itemCount: todos.length,
                      maxVisible: 4,
                      itemHeight: 56,
                      itemBuilder: (index) {
                        final t = todos[index];
                        return _TodoItem(
                          index: index + 1,
                          item: t,
                          last: index == todos.length - 1,
                          onEdit: () => _showTodoSheet(context, todo: t),
                          onDelete: () => TodoStore.remove(t.id),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── 重要事件 ──
              _SectionHeader(
                title: '重要事件',
                actionColor: _eventColor,
                onAdd: () => _showAddEventSheet(context),
              ),
              _SectionCard(
                child: _LimitedList(
                  itemCount: futureEvents.length + pastEvents.length,
                  maxVisible: 4,
                  itemHeight: 56,
                  itemBuilder: (index) {
                    final isFuture = index < futureEvents.length;
                    final e = isFuture
                        ? futureEvents[index]
                        : pastEvents[index - futureEvents.length];
                    return _EventItem(
                      ev: e,
                      past: !isFuture,
                      last:
                          index == futureEvents.length + pastEvents.length - 1,
                      onEdit: () => _showEventSheet(context, event: e),
                      onDelete: () => ImportantDateStore.removeEvent(e.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── 生日 ──
              _SectionHeader(
                title: '生日',
                actionColor: AppColors.birthday,
                onAdd: () => _showBirthdaySheet(context),
              ),
              _SectionCard(
                child: _LimitedList(
                  itemCount: upcomingBirthdays.length,
                  maxVisible: 4,
                  itemHeight: 56,
                  itemBuilder: (index) {
                    final birthday = upcomingBirthdays[index];
                    return _BirthdayItem(
                      b: birthday,
                      today: today,
                      last: index == upcomingBirthdays.length - 1,
                      onEdit: () =>
                          _showBirthdaySheet(context, birthday: birthday),
                      onDelete: () =>
                          ImportantDateStore.removeBirthday(birthday.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── 纪念日 ──
              _SectionHeader(
                title: '纪念日',
                actionColor: _anniversaryColor,
                onAdd: () => _showAnniversarySheet(context),
              ),
              _SectionCard(
                child: _LimitedList(
                  itemCount: upcomingAnniversaries.length,
                  maxVisible: 4,
                  itemHeight: 56,
                  itemBuilder: (index) {
                    final anniversary = upcomingAnniversaries[index];
                    return _AnniversaryItem(
                      a: anniversary,
                      today: today,
                      last: index == upcomingAnniversaries.length - 1,
                      onEdit: () => _showAnniversarySheet(context,
                          anniversary: anniversary),
                      onDelete: () =>
                          ImportantDateStore.removeAnniversary(anniversary.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTodoSheet(BuildContext context, {TodoItem? todo}) {
    _todoCtrl.text = todo?.text ?? '';
    final editing = todo != null;
    final editingTodo = todo;
    _showJournalPopup(
      context,
      _SimpleTextSheet(
        title: editing ? '修改待办事项' : '添加待办事项',
        hint: '待办内容',
        buttonText: editing ? '保存' : '添加',
        color: _todoAccent,
        controller: _todoCtrl,
        onSubmit: () {
          if (editing) {
            final text = _todoCtrl.text.trim();
            if (text.isEmpty) return;
            TodoStore.update(editingTodo!.id, text);
            _todoCtrl.clear();
          } else {
            _addTodo(_todoCtrl.text);
          }
          Navigator.pop(context);
        },
      ),
      top: 94,
    );
  }

  void _showAddEventSheet(BuildContext context) => _showEventSheet(context);

  void _showEventSheet(BuildContext context, {ImportantEvent? event}) {
    // 重要事件支持新增和修改，日期统一通过年月日滚轮选择。
    _showJournalPopup(
      context,
      _EventSheet(
        event: event,
        onSave: (title, startDate, endDate, note) {
          ImportantDateStore.saveEvent(
            id: event?.id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            note: note,
          );
        },
      ),
      top: 190,
    );
  }

  void _showBirthdaySheet(BuildContext context, {BirthdayDate? birthday}) {
    _showJournalPopup(
      context,
      _BirthdaySheet(
        birthday: birthday,
        onSave: (name, solar, lunar) {
          ImportantDateStore.saveBirthday(
            id: birthday?.id,
            name: name,
            solar: solar,
            lunar: lunar,
          );
        },
      ),
      top: 292,
    );
  }

  void _showAnniversarySheet(BuildContext context,
      {AnniversaryDate? anniversary}) {
    _showJournalPopup(
      context,
      _AnniversarySheet(
        anniversary: anniversary,
        onSave: (name, solar, lunar) {
          ImportantDateStore.saveAnniversary(
            id: anniversary?.id,
            name: name,
            solar: solar,
            lunar: lunar,
          );
        },
      ),
      top: 260,
    );
  }
}

// 分区标题。
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color actionColor;
  final VoidCallback? onAdd;
  const _SectionHeader(
      {required this.title, required this.actionColor, this.onAdd});

  @override
  Widget build(BuildContext context) {
    // 各分区标题的统一样式；有新增入口时在右侧展示加号动作。
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          const Spacer(),
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Row(
                children: [
                  Icon(Icons.add, size: 14, color: actionColor),
                  Text('添加',
                      style: TextStyle(fontSize: 11, color: actionColor)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// 左滑删除时展示的红色背景（所有列表项共用）。
Widget _dismissBg({Color color = AppColors.brand}) => Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      color: color.withValues(alpha: 0.10),
      child: Icon(Icons.delete_outline, color: color, size: 20),
    );

class _RecordPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final bool muted;
  const _RecordPill({
    required this.text,
    required this.color,
    required this.background,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2, right: 10),
      constraints: const BoxConstraints(minWidth: 34, maxWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? AppColors.bgTab : background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: muted ? AppColors.textSecondary : color,
          height: 1.25,
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final Key rowKey;
  final bool last;
  final Color color;
  final bool muted;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordRow({
    required this.rowKey,
    required this.last,
    required this.color,
    required this.leading,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    this.subtitle,
    this.trailing,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: rowKey,
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      background: _dismissBg(color: color),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onEdit();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppColors.border, width: 0.5))),
          child: Opacity(
            opacity: muted ? 0.55 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w400,
                          )),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.25,
                                  color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordTrailing extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _RecordTrailing({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.15,
              color: color,
            )),
        Text(label,
            style: const TextStyle(
                fontSize: 11, height: 1.2, color: AppColors.textSecondary)),
      ],
    );
  }
}

// 分区卡片。
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    // 记录页的通用白色卡片容器，内部子项自行处理分割线。
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _LimitedList extends StatelessWidget {
  final int itemCount;
  final int maxVisible;
  final double itemHeight;
  final Widget Function(int index) itemBuilder;
  const _LimitedList({
    required this.itemCount,
    required this.maxVisible,
    required this.itemHeight,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('暂无记录',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
      );
    }
    final list = ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: itemCount <= maxVisible,
      physics: itemCount > maxVisible
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, index) => itemBuilder(index),
    );
    if (itemCount <= maxVisible) return list;
    return SizedBox(height: maxVisible * itemHeight, child: list);
  }
}

// 待办项。
class _TodoItem extends StatelessWidget {
  final int index;
  final TodoItem item;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TodoItem({
    required this.index,
    required this.item,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _RecordRow(
      rowKey: ValueKey(item.id),
      last: last,
      color: _todoAccent,
      leading: _RecordPill(
        text: '$index',
        color: _todoAccent,
        background: _todoAccentLight,
      ),
      title: item.text,
      trailing:
          const Icon(Icons.chevron_right, size: 15, color: AppColors.border),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// 重要事件项。
class _EventItem extends StatelessWidget {
  final ImportantEvent ev;
  final bool past;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EventItem({
    required this.ev,
    required this.past,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _RecordRow(
      rowKey: ValueKey(ev.id),
      last: last,
      color: _eventColor,
      muted: past,
      leading: _RecordPill(
        text: ev.date,
        color: _eventColor,
        background: _eventColorLight,
        muted: past,
      ),
      title: ev.title,
      subtitle: ev.note,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// 生日项。
class _BirthdayItem extends StatelessWidget {
  final BirthdayDate b;
  final DateTime today;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BirthdayItem({
    required this.b,
    required this.today,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final days = b.daysUntilBirthdayFrom(today);
    return _RecordRow(
      rowKey: ValueKey(b.id),
      last: last,
      color: AppColors.birthday,
      leading: _RecordPill(
        text: days == 0 ? '今天' : '$days天',
        color: AppColors.birthday,
        background: days <= 7 ? AppColors.birthdayLight : AppColors.bgPage,
      ),
      title: b.name,
      subtitle: '阳历 ${b.solarDate} · 阴历 ${b.lunarDate}',
      trailing: _RecordTrailing(
        value: '${b.ageFrom(today)}岁',
        label: '今年',
        color: AppColors.birthday,
      ),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// 纪念日项。
class _AnniversaryItem extends StatelessWidget {
  final AnniversaryDate a;
  final DateTime today;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AnniversaryItem({
    required this.a,
    required this.today,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final days = a.daysUntilAnniversaryFrom(today);
    return _RecordRow(
      rowKey: ValueKey(a.id),
      last: last,
      color: _anniversaryColor,
      leading: _RecordPill(
        text: days == 0 ? '今天' : '$days天',
        color: _anniversaryColor,
        background: days <= 7 ? _anniversaryColorLight : AppColors.bgPage,
      ),
      title: a.name,
      subtitle: '阴历 ${a.lunarDate} · 阳历 ${a.solarDate}',
      trailing: _RecordTrailing(
        value: '第${a.yearsFrom(today)}年',
        label: '周年',
        color: _anniversaryColor,
      ),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// 弹窗面板。
class _SimpleTextSheet extends StatelessWidget {
  final String title;
  final String hint;
  final String buttonText;
  final Color color;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _SimpleTextSheet({
    required this.title,
    required this.hint,
    required this.buttonText,
    required this.color,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: title,
      buttonText: buttonText,
      color: color,
      onPressed: () {
        if (controller.text.trim().isEmpty) return;
        onSubmit();
      },
      children: [
        _SheetField(ctrl: controller, hint: hint, color: color),
      ],
    );
  }
}

class _EventSheet extends StatefulWidget {
  final ImportantEvent? event;
  final void Function(
    String title,
    DateTime startDate,
    DateTime endDate,
    String note,
  ) onSave;
  const _EventSheet({this.event, required this.onSave});

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleCtrl = TextEditingController(text: event?.title ?? '');
    _noteCtrl = TextEditingController(text: event?.note ?? '');
    _startDate = event?.startDate ?? _today;
    _endDate = event?.endDate ?? _startDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    return _SheetFrame(
      title: editing ? '修改重要事件' : '添加重要事件',
      buttonText: editing ? '保存' : '添加',
      color: _eventColor,
      onPressed: () {
        if (_titleCtrl.text.trim().isEmpty) return;
        widget.onSave(
          _titleCtrl.text.trim(),
          _startDate,
          _endDate,
          _noteCtrl.text.trim(),
        );
        Navigator.pop(context);
      },
      children: [
        _SheetField(ctrl: _titleCtrl, hint: '事件名称（如：考研报名截止）', color: _eventColor),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '开始时间',
          value: _startDate,
          color: _eventColor,
          onChanged: (date) => setState(() {
            _startDate = date;
            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
          }),
        ),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '结束时间',
          value: _endDate,
          color: _eventColor,
          onChanged: (date) => setState(() => _endDate = date),
        ),
        const SizedBox(height: 10),
        _SheetField(ctrl: _noteCtrl, hint: '备注（可选）', color: _eventColor),
      ],
    );
  }
}

class _BirthdaySheet extends StatefulWidget {
  final BirthdayDate? birthday;
  final void Function(String name, DateTime solar, DateTime lunar) onSave;
  const _BirthdaySheet({this.birthday, required this.onSave});

  @override
  State<_BirthdaySheet> createState() => _BirthdaySheetState();
}

class _BirthdaySheetState extends State<_BirthdaySheet> {
  late final TextEditingController _nameCtrl;
  late DateTime _solarDate;
  late DateTime _lunarDate;

  @override
  void initState() {
    super.initState();
    final birthday = widget.birthday;
    _nameCtrl = TextEditingController(text: birthday?.name ?? '');
    _solarDate = birthday == null
        ? DateTime(1998, 4, 4)
        : DateTime(birthday.solarYear, birthday.solarMonth, birthday.solarDay);
    _lunarDate = birthday == null
        ? DateTime(1998, 3, 8)
        : DateTime(birthday.lunarYear, birthday.lunarMonth, birthday.lunarDay);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.birthday != null;
    return _SheetFrame(
      title: editing ? '修改生日' : '添加生日',
      buttonText: editing ? '保存' : '添加',
      color: AppColors.birthday,
      onPressed: () {
        if (_nameCtrl.text.trim().isEmpty) return;
        widget.onSave(_nameCtrl.text.trim(), _solarDate, _lunarDate);
        Navigator.pop(context);
      },
      children: [
        _SheetField(ctrl: _nameCtrl, hint: '姓名', color: AppColors.birthday),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '阳历生日',
          value: _solarDate,
          color: AppColors.birthday,
          yearStart: 1930,
          yearEnd: _today.year,
          onChanged: (date) => setState(() => _solarDate = date),
        ),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '阴历生日',
          value: _lunarDate,
          color: AppColors.birthday,
          yearStart: 1930,
          yearEnd: _today.year,
          onChanged: (date) => setState(() => _lunarDate = date),
        ),
      ],
    );
  }
}

class _AnniversarySheet extends StatefulWidget {
  final AnniversaryDate? anniversary;
  final void Function(String name, DateTime solar, DateTime lunar) onSave;
  const _AnniversarySheet({this.anniversary, required this.onSave});

  @override
  State<_AnniversarySheet> createState() => _AnniversarySheetState();
}

class _AnniversarySheetState extends State<_AnniversarySheet> {
  late final TextEditingController _nameCtrl;
  late DateTime _solarDate;
  late DateTime _lunarDate;

  @override
  void initState() {
    super.initState();
    final anniversary = widget.anniversary;
    _nameCtrl = TextEditingController(text: anniversary?.name ?? '');
    _solarDate = anniversary == null
        ? _today
        : DateTime(anniversary.solarYear, anniversary.solarMonth,
            anniversary.solarDay);
    _lunarDate = anniversary == null
        ? _today
        : DateTime(anniversary.lunarYear, anniversary.lunarMonth,
            anniversary.lunarDay);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.anniversary != null;
    return _SheetFrame(
      title: editing ? '修改纪念日' : '添加纪念日',
      buttonText: editing ? '保存' : '添加',
      color: _anniversaryColor,
      onPressed: () {
        if (_nameCtrl.text.trim().isEmpty) return;
        widget.onSave(_nameCtrl.text.trim(), _solarDate, _lunarDate);
        Navigator.pop(context);
      },
      children: [
        _SheetField(
            ctrl: _nameCtrl, hint: '纪念日名称', color: _anniversaryColor),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '阳历日期',
          value: _solarDate,
          color: _anniversaryColor,
          yearStart: 1970,
          yearEnd: _today.year,
          onChanged: (date) => setState(() => _solarDate = date),
        ),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '阴历日期',
          value: _lunarDate,
          color: _anniversaryColor,
          yearStart: 1970,
          yearEnd: _today.year,
          onChanged: (date) => setState(() => _lunarDate = date),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final String buttonText;
  final Color color;
  final VoidCallback onPressed;
  final List<Widget> children;
  const _SheetFrame({
    required this.title,
    required this.buttonText,
    required this.color,
    required this.onPressed,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text(buttonText,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Color color;
  const _SheetField(
      {required this.ctrl, required this.hint, required this.color});

  @override
  Widget build(BuildContext context) {
    // 弹窗中复用的输入框样式。
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bgPage,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
    );
  }
}

class _DateWheelField extends StatelessWidget {
  final String label;
  final DateTime value;
  final Color color;
  final ValueChanged<DateTime> onChanged;
  final int yearStart;
  final int yearEnd;
  const _DateWheelField({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    this.yearStart = 2020,
    this.yearEnd = 2035,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showGeneralDialog<DateTime>(
          context: context,
          barrierDismissible: true,
          barrierLabel: '关闭日期选择',
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
                child: Center(
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: _DateWheelSheet(
                        initial: value,
                        color: color,
                        yearStart: yearStart,
                        yearEnd: yearEnd,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
            Text('${value.year}年${value.month}月${value.day}日',
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

class _DateWheelSheet extends StatefulWidget {
  final DateTime initial;
  final Color color;
  final int yearStart;
  final int yearEnd;
  const _DateWheelSheet({
    required this.initial,
    required this.color,
    required this.yearStart,
    required this.yearEnd,
  });

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year.clamp(widget.yearStart, widget.yearEnd);
    _month = widget.initial.month;
    _day = widget.initial.day;
    _fixDay();
    _yearCtrl =
        FixedExtentScrollController(initialItem: _year - widget.yearStart);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _fixDay({bool syncController = false}) {
    final maxDay = DateUtils.getDaysInMonth(_year, _month);
    if (_day <= maxDay) return;
    _day = maxDay;
    if (!syncController) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dayCtrl.hasClients) {
        _dayCtrl.jumpToItem(_day - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
        widget.yearEnd - widget.yearStart + 1, (i) => widget.yearStart + i);
    final maxDay = DateUtils.getDaysInMonth(_year, _month);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, DateTime(_year, _month, _day)),
                    child: Text('确定',
                        style: TextStyle(
                            color: widget.color, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _WheelColumn(
                    key: ValueKey('year-${widget.yearStart}-${widget.yearEnd}'),
                    controller: _yearCtrl,
                    count: years.length,
                    labelBuilder: (index) => '${years[index]}年',
                    onSelected: (index) => setState(() {
                      _year = years[index];
                      _fixDay(syncController: true);
                    }),
                  ),
                  _WheelColumn(
                    key: const ValueKey('month'),
                    controller: _monthCtrl,
                    count: 12,
                    labelBuilder: (index) => '${index + 1}月',
                    onSelected: (index) => setState(() {
                      _month = index + 1;
                      _fixDay(syncController: true);
                    }),
                  ),
                  _WheelColumn(
                    key: ValueKey('day-$maxDay'),
                    controller: _dayCtrl,
                    count: maxDay,
                    labelBuilder: (index) => '${index + 1}日',
                    onSelected: (index) => setState(() => _day = index + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelected;
  const _WheelColumn({
    super.key,
    required this.controller,
    required this.count,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: 36,
        onSelectedItemChanged: onSelected,
        childCount: count,
        itemBuilder: (_, index) => Center(
          child: Text(labelBuilder(index),
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}
