import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_theme.dart';
import 'health_store.dart';
import 'important_date_store.dart';
import 'profile_store.dart';
import 'screens/calendar_screen.dart';
import 'screens/health_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/profile_screen.dart';
import 'storage_service.dart';
import 'todo_store.dart';
import 'weight_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.init();
  await Future.wait([
    AppThemeController.load(),
    ProfileStore.load(),
    TodoStore.load(),
    WeightStore.load(),
    HealthStore.load(),
    ImportantDateStore.load(),
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const SuiSuiApp());
}

class SuiSuiApp extends StatelessWidget {
  const SuiSuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppThemeController.index, AppThemeController.fontScale]),
      builder: (context, _) {
        final palette = AppThemeController.palette;
        final scale = AppThemeController.fontScale.value;
        return MaterialApp(
          title: '岁岁',
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: palette.brand,
              secondary: palette.brand,
              surface: AppColors.bgPage,
            ),
            scaffoldBackgroundColor: AppColors.bgPage,
            fontFamily: 'sans-serif',
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.bgPage,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? palette.brand : null),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? palette.light : null),
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: palette.brand,
              thumbColor: palette.brand,
              inactiveTrackColor: AppColors.bgTab,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageCtrl,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) {
          if (i == _index) return;
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        children: const [
          _KeepAlivePage(child: CalendarScreen()),
          _KeepAlivePage(child: HealthScreen()),
          _KeepAlivePage(child: JournalScreen()),
          _KeepAlivePage(child: ProfileScreen()),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        current: _index,
        onTap: _onTabTap,
      ),
    );
  }
}

// 保持页面在 PageView 切换后不被销毁。
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.current, required this.onTap});

  static const _tabs = [
    (Icons.calendar_month_outlined, Icons.calendar_month, '日历'),
    (Icons.favorite_border, Icons.favorite, '健康'),
    (Icons.book_outlined, Icons.book, '记录'),
    (Icons.person_outline, Icons.person, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeController.palette;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final active = current == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              active ? palette.light : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Icon(
                          active ? tab.$2 : tab.$1,
                          color: active
                              ? palette.brand
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.$3,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              active ? palette.brand : AppColors.textSecondary,
                          fontWeight:
                              active ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
