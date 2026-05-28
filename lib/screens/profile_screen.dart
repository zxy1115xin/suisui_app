import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../profile_store.dart';
import '../weight_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int get _age {
    final today = appToday;
    var age = today.year - ProfileStore.birthday.year;
    final birthdayThisYear = DateTime(
        today.year, ProfileStore.birthday.month, ProfileStore.birthday.day);
    if (today.isBefore(birthdayThisYear)) age -= 1;
    return age;
  }

  String get _birthdayText => '${ProfileStore.birthday.year}年'
      '${ProfileStore.birthday.month}月'
      '${ProfileStore.birthday.day}日';

  double _bmiForWeight(double weight) {
    final h = ProfileStore.height / 100;
    return weight / (h * h);
  }

  String _bmiLabelFor(double bmi) {
    if (bmi < 18.5) return '偏瘦';
    if (bmi < 24.0) return '正常';
    if (bmi < 28.0) return '偏重';
    return '肥胖';
  }

  Color _bmiColorFor(double bmi, AppThemePalette theme) {
    if (bmi < 18.5) return const Color(0xFF4A8FB5);
    if (bmi < 24.0) return theme.brand;
    if (bmi < 28.0) return AppColors.birthday;
    return AppColors.period;
  }

  @override
  void initState() {
    super.initState();
    WeightStore.weights.addListener(_refresh);
    ProfileStore.version.addListener(_refresh);
  }

  @override
  void dispose() {
    WeightStore.weights.removeListener(_refresh);
    ProfileStore.version.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<T?> _showProfilePopup<T>(Widget child) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭个人信息编辑窗',
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
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProfileEditor() async {
    final result = await _showProfilePopup<_ProfileEditResult>(
      _ProfileEditor(
        nickname: ProfileStore.nickname,
        birthday: ProfileStore.birthday,
        height: ProfileStore.height,
        color: AppThemeController.palette.brand,
      ),
    );
    if (result == null) return;
    ProfileStore.save(
      newNickname: result.nickname,
      newBirthday: result.birthday,
      newHeight: result.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeController.palette;
    final todayWeight = WeightStore.todayWeight;
    final bmi = _bmiForWeight(todayWeight);
    final bmiColor = _bmiColorFor(bmi, theme);
    final bmiLabel = _bmiLabelFor(bmi);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('我的',
              style: TextStyle(
                  fontFamily: 'XinDiXiaWuCha',
                  fontSize: 22,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _SLabel('个人信息'),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ProfileStore.nickname,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary)),
                          Text(
                              '生日 $_birthdayText · $_age岁 · 身高 ${ProfileStore.height.toStringAsFixed(0)}cm',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showProfileEditor,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 14, color: theme.brand),
                          const SizedBox(width: 3),
                          Text('修改',
                              style: TextStyle(
                                  fontSize: 11, color: theme.brand)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BMI 指数',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(bmi.toStringAsFixed(1),
                                  style:
                                      TextStyle(fontSize: 20, color: bmiColor)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: bmiColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(bmiLabel,
                                    style: TextStyle(
                                        fontSize: 11, color: bmiColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 8,
                              child: LinearProgressIndicator(
                                value: ((bmi - 15) / 20).clamp(0.0, 1.0),
                                backgroundColor: AppColors.bgTab,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(theme.brand),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('偏瘦',
                                  style: TextStyle(
                                      fontSize: 11,
                                      height: 1.1,
                                      color: AppColors.textSecondary)),
                              Text('正常',
                                  style: TextStyle(
                                      fontSize: 11,
                                      height: 1.1,
                                      color: AppColors.textSecondary)),
                              Text('偏重',
                                  style: TextStyle(
                                      fontSize: 11,
                                      height: 1.1,
                                      color: AppColors.textSecondary)),
                              Text('肥胖',
                                  style: TextStyle(
                                      fontSize: 11,
                                      height: 1.1,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SLabel('外观'),
          _AppearanceCard(theme: theme),
          const SizedBox(height: 16),
          _SLabel('其他'),
          _Card(
            children: [
              _NavRow(
                  icon: Icons.download_outlined,
                  label: '导出健康数据',
                  value: 'CSV / JSON'),
              _NavRow(
                  icon: Icons.security_outlined,
                  label: '隐私说明',
                  value: '本地存储',
                  last: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileEditResult {
  final String nickname;
  final DateTime birthday;
  final double height;
  const _ProfileEditResult({
    required this.nickname,
    required this.birthday,
    required this.height,
  });
}

class _ProfileEditor extends StatefulWidget {
  final String nickname;
  final DateTime birthday;
  final double height;
  final Color color;
  const _ProfileEditor({
    required this.nickname,
    required this.birthday,
    required this.height,
    required this.color,
  });

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _heightCtrl;
  late DateTime _birthday;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.nickname);
    _birthday = widget.birthday;
    _heightCtrl = TextEditingController(text: widget.height.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  Future<void> _showBirthdayPicker() async {
    const minYear = 1930;
    final maxYear = appToday.year;
    var year = _birthday.year.clamp(minYear, maxYear).toInt();
    var month = _birthday.month;
    var day =
        _birthday.day.clamp(1, DateUtils.getDaysInMonth(year, month)).toInt();
    final yearCtrl = FixedExtentScrollController(initialItem: year - minYear);
    final monthCtrl = FixedExtentScrollController(initialItem: month - 1);
    final dayCtrl = FixedExtentScrollController(initialItem: day - 1);

    try {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, modalSetState) {
              final maxDay = DateUtils.getDaysInMonth(year, month);
              if (day > maxDay) {
                day = maxDay;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dayCtrl.hasClients) dayCtrl.jumpToItem(day - 1);
                });
              }

              Widget wheel({
                required FixedExtentScrollController controller,
                required int count,
                required int start,
                required String unit,
                required ValueChanged<int> onChanged,
              }) {
                return Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 38,
                    useMagnifier: true,
                    magnification: 1.08,
                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                      background: widget.color.withAlpha(18),
                    ),
                    onSelectedItemChanged: (index) => onChanged(start + index),
                    children: List.generate(count, (index) {
                      final value = start + index;
                      return Center(
                        child: Text(
                          '$value $unit',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }

              return Container(
                height: 286,
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CupertinoButton(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              onPressed: () {
                                setState(() =>
                                    _birthday = DateTime(year, month, day));
                                Navigator.pop(context);
                              },
                              child: Text('完成',
                                  style: TextStyle(color: widget.color)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            wheel(
                              controller: yearCtrl,
                              count: maxYear - minYear + 1,
                              start: minYear,
                              unit: '年',
                              onChanged: (value) =>
                                  modalSetState(() => year = value),
                            ),
                            wheel(
                              controller: monthCtrl,
                              count: 12,
                              start: 1,
                              unit: '月',
                              onChanged: (value) =>
                                  modalSetState(() => month = value),
                            ),
                            wheel(
                              controller: dayCtrl,
                              count: maxDay,
                              start: 1,
                              unit: '日',
                              onChanged: (value) =>
                                  modalSetState(() => day = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      yearCtrl.dispose();
      monthCtrl.dispose();
      dayCtrl.dispose();
    }
  }

  void _save() {
    final nickname = _nicknameCtrl.text.trim();
    final height = double.tryParse(_heightCtrl.text.trim());
    if (nickname.isEmpty) {
      setState(() => _error = '昵称不能为空');
      return;
    }
    if (height == null || height < 80 || height > 230) {
      setState(() => _error = '身高需在 80-230 cm 之间');
      return;
    }
    Navigator.pop(
      context,
      _ProfileEditResult(
          nickname: nickname, birthday: _birthday, height: height),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
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
            borderSide: BorderSide(color: widget.color)),
      );

  @override
  Widget build(BuildContext context) {
    Widget labeledField(String label, Widget field) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 5),
          field,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('修改个人信息',
              style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          labeledField(
            '昵称',
            TextField(
              controller: _nicknameCtrl,
              decoration: _decoration('请输入昵称'),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          labeledField(
            '生日',
            GestureDetector(
              onTap: _showBirthdayPicker,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_formatDate(_birthday),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ),
                    Icon(Icons.keyboard_arrow_down,
                        size: 18, color: widget.color),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          labeledField(
            '身高',
            TextField(
              controller: _heightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoration('单位 cm'),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(fontSize: 11, color: AppColors.holiday)),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);

  @override
  Widget build(BuildContext context) {
    // 设置页分组小标题。
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    // 个人页统一卡片容器，子项之间通过分割线或底部分割线分隔。
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
        child: Column(children: children),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  const _NavRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.last = false});

  @override
  Widget build(BuildContext context) {
    // 普通设置导航行，用于尚未展开的二级设置入口。
    final theme = AppThemeController.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5))),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.border),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatefulWidget {
  final AppThemePalette theme;
  const _AppearanceCard({required this.theme});

  @override
  State<_AppearanceCard> createState() => _AppearanceCardState();
}

class _AppearanceCardState extends State<_AppearanceCard> {
  @override
  Widget build(BuildContext context) {
    final scaleIdx = AppThemeController.fontScaleIndex;
    return _Card(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields_outlined, size: 17, color: widget.theme.brand),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('字体大小',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                  Text(fontScaleLabels[scaleIdx],
                      style: TextStyle(fontSize: 11, color: widget.theme.brand)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  value: scaleIdx.toDouble(),
                  min: 0,
                  max: (fontScaleSteps.length - 1).toDouble(),
                  divisions: fontScaleSteps.length - 1,
                  onChanged: (v) {
                    final idx = v.round();
                    AppThemeController.selectFontScale(idx);
                    setState(() {});
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: fontScaleLabels
                      .map((l) => Text(l,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
