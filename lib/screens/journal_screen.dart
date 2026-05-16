import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../important_date_store.dart';
import '../todo_store.dart';

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

const _todoAccent = AppColors.brand;
const _todoAccentLight = AppColors.brandLight;
const _eventRed = Color(0xFFD76F72);
const _eventRedLight = Color(0xFFF8DCDD);

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
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _todayTimer =
        Timer(tomorrow.difference(now) + const Duration(seconds: 1), () {
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
      barrierColor: Colors.black.withOpacity(0.06),
      transitionDuration: const Duration(milliseconds: 140),
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
                  padding: EdgeInsets.fromLTRB(16, top, 16, 20),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 360,
                        maxHeight:
                            MediaQuery.of(dialogContext).size.height - top - 40,
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
                      itemHeight: 48,
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
                actionColor: const Color.fromARGB(255, 214, 127, 130),
                onAdd: () => _showAddEventSheet(context),
              ),
              _SectionCard(
                child: _LimitedList(
                  itemCount: futureEvents.length + pastEvents.length,
                  maxVisible: 4,
                  itemHeight: 64,
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
                  itemHeight: 72,
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
                actionColor: const Color.fromARGB(255, 150, 121, 182),
                onAdd: () => _showAnniversarySheet(context),
              ),
              _SectionCard(
                child: _LimitedList(
                  itemCount: upcomingAnniversaries.length,
                  maxVisible: 4,
                  itemHeight: 72,
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
      itemBuilder: (_, index) =>
          SizedBox(height: itemHeight, child: itemBuilder(index)),
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
    // 待办行：左侧只展示序号，只有右侧删除键会移除待办。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _todoAccentLight,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text('$index',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _todoAccent,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close, size: 16, color: AppColors.border),
            ),
          ],
        ),
      ),
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
    // 重要事件行：已发生事件只降低透明度，仍保留可读文本。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Opacity(
          opacity: past ? 0.55 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: past ? AppColors.bgTab : _eventRedLight,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(ev.date,
                    style: TextStyle(
                        fontSize: 11,
                        color: past ? AppColors.textSecondary : _eventRed)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ev.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        )),
                    if (ev.note.isNotEmpty)
                      Text(ev.note,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child:
                    const Icon(Icons.close, size: 16, color: AppColors.border),
              ),
            ],
          ),
        ),
      ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 42,
              decoration: BoxDecoration(
                color: days <= 7 ? AppColors.birthdayLight : AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.birthdayLight),
              ),
              child: Center(
                child: days == 0
                    ? const Text('今天',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.birthday,
                            fontWeight: FontWeight.w600))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$days',
                              style: const TextStyle(
                                  fontSize: 15, color: AppColors.birthday)),
                          const Text('天',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  Text('阳历 ${b.solarDate} · 阴历 ${b.lunarDate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${b.ageFrom(today)}岁',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.1,
                        color: AppColors.birthday,
                      )),
                  const SizedBox(height: 2),
                  const Text('今年',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const SizedBox(
                width: 28,
                height: 32,
                child: Center(
                  child: Icon(Icons.close, size: 16, color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 42,
              decoration: BoxDecoration(
                color: days <= 7 ? const Color(0xFFF0E8FA) : AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD7C4EE)),
              ),
              child: Center(
                child: days == 0
                    ? const Text('今天',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8B6BAE),
                            fontWeight: FontWeight.w600))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$days',
                              style: const TextStyle(
                                  fontSize: 15, color: Color(0xFF8B6BAE))),
                          const Text('天',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  Text('阴历 ${a.lunarDate} · 阳历 ${a.solarDate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 66,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('第${a.yearsFrom(today)}年',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.1,
                        color: Color(0xFF8B6BAE),
                      )),
                  const SizedBox(height: 2),
                  const Text('周年',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const SizedBox(
                width: 28,
                height: 32,
                child: Center(
                  child: Icon(Icons.close, size: 16, color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
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
      color: _eventRed,
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
        _SheetField(ctrl: _titleCtrl, hint: '事件名称（如：考研报名截止）', color: _eventRed),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '开始时间',
          value: _startDate,
          color: _eventRed,
          onChanged: (date) => setState(() {
            _startDate = date;
            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
          }),
        ),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '结束时间',
          value: _endDate,
          color: _eventRed,
          onChanged: (date) => setState(() => _endDate = date),
        ),
        const SizedBox(height: 10),
        _SheetField(ctrl: _noteCtrl, hint: '备注（可选）', color: _eventRed),
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
      color: const Color(0xFF8B6BAE),
      onPressed: () {
        if (_nameCtrl.text.trim().isEmpty) return;
        widget.onSave(_nameCtrl.text.trim(), _solarDate, _lunarDate);
        Navigator.pop(context);
      },
      children: [
        _SheetField(
            ctrl: _nameCtrl, hint: '纪念日名称', color: const Color(0xFF8B6BAE)),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '阳历日期',
          value: _solarDate,
          color: const Color(0xFF8B6BAE),
          yearStart: 1970,
          yearEnd: _today.year,
          onChanged: (date) => setState(() => _solarDate = date),
        ),
        const SizedBox(height: 10),
        _DateWheelField(
          label: '阴历日期',
          value: _lunarDate,
          color: const Color(0xFF8B6BAE),
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
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
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
          barrierColor: Colors.black.withOpacity(0.06),
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

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year.clamp(widget.yearStart, widget.yearEnd);
    _month = widget.initial.month;
    _day = widget.initial.day;
    _fixDay();
  }

  void _fixDay() {
    final maxDay = DateUtils.getDaysInMonth(_year, _month);
    if (_day > maxDay) _day = maxDay;
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
                    controller: FixedExtentScrollController(
                        initialItem: _year - widget.yearStart),
                    count: years.length,
                    labelBuilder: (index) => '${years[index]}年',
                    onSelected: (index) => setState(() {
                      _year = years[index];
                      _fixDay();
                    }),
                  ),
                  _WheelColumn(
                    key: const ValueKey('month'),
                    controller:
                        FixedExtentScrollController(initialItem: _month - 1),
                    count: 12,
                    labelBuilder: (index) => '${index + 1}月',
                    onSelected: (index) => setState(() {
                      _month = index + 1;
                      _fixDay();
                    }),
                  ),
                  _WheelColumn(
                    key: ValueKey('day-$maxDay-$_day'),
                    controller:
                        FixedExtentScrollController(initialItem: _day - 1),
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
