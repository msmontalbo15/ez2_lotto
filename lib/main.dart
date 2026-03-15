// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_provider.dart';
import 'constants.dart';
import 'helpers.dart';
import 'widgets/common.dart';
import 'screens/today_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/ticket_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const EZ2App(),
    ),
  );
}

class EZ2App extends StatelessWidget {
  const EZ2App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EZ2 Lotto',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          useMaterial3: true,
          fontFamily: 'Georgia',
          scaffoldBackgroundColor: AppColors.bgGradStart,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black38,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: AppColors.primaryDark,
              statusBarIconBrightness: Brightness.light,
            ),
          ),
        ),
        home: const _HomeShell(),
      );
}

// ── Main shell with bottom nav ────────────────────────────────
class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;

  static const _screens = [
    TodayScreen(),
    HistoryScreen(),
    StatsScreen(),
    TicketScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final ph = getPHTime();
    final timeStr =
        '${ph.hour.toString().padLeft(2, '0')}:${ph.minute.toString().padLeft(2, '0')}:${ph.second.toString().padLeft(2, '0')}';

    // Force rebuild for clock
    prov.currentTime;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgGradStart,
              AppColors.bgGradMid,
              AppColors.bgGradEnd
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Column(children: [
          // ── App Bar ────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 14,
              left: 18,
              right: 18,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryLight,
                  AppColors.primary,
                  AppColors.primaryDark
                ],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black38, blurRadius: 20, offset: Offset(0, 5))
              ],
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: const [
                    Text('🎱', style: TextStyle(fontSize: 36)),
                    SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EZ2 / 2D Lotto',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1)),
                          Text('PCSO • 2PM · 5PM · 9PM',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFFFFCDD2))),
                        ]),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    OnlineIndicator(
                        isOnline:
                            prov.allRows.isNotEmpty || prov.lastUpdate != null),
                  ]),
                ]),
          ),

          // ── Screen content ─────────────────────────────
          Expanded(child: _screens[_tab]),
        ]),
      ),

      // ── Bottom navigation ─────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFF3E0),
        shadowColor: Colors.black12,
        elevation: 8,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt, color: AppColors.accent),
            label: 'Resulta',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.accent),
            label: 'Kasaysayan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.accent),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon:
                Icon(Icons.confirmation_number, color: AppColors.accent),
            label: 'I-check',
          ),
        ],
      ),
    );
  }
}
