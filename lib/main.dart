import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_theme.dart';
import 'screens/calendar_screen.dart';
import 'screens/health_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return ValueListenableBuilder<int>(
      valueListenable: AppThemeController.index,
      builder: (context, _, __) {
        final palette = AppThemeController.palette;
        return MaterialApp(
          title: '岁岁',
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.12,
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

  static const _pages = [
    CalendarScreen(),
    HealthScreen(),
    JournalScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _BottomNav(
        current: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
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
                      Icon(
                        active ? tab.$2 : tab.$1,
                        color: active ? palette.brand : AppColors.textSecondary,
                        size: 26,
                      ),
                      const SizedBox(height: 3),
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
