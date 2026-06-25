// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_locale.dart';
import 'app_provider.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import 'constants.dart';
import 'responsive.dart';
import 'screens/today_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/ticket_screen.dart';
import 'screens/settings_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey),
    CacheService.init(),
  ]);

  // Initialize connectivity monitoring (with fallback if it fails)
  try {
    await ConnectivityService.instance.init();
  } catch (e) {
    debugPrint('Connectivity init failed: $e');
  }

  // Root/Jailbreak detection guard
  bool isSecure = true;
  if (!kDebugMode) {
    try {
      final isJailbroken = await FlutterJailbreakDetection.jailbroken;
      final isDeveloperMode = await FlutterJailbreakDetection.developerMode;
      if (isJailbroken || isDeveloperMode) {
        isSecure = false;
      }
    } catch (e) {
      debugPrint('Jailbreak detection error: $e');
    }
  }

  runApp(EZ2App(isSecure: isSecure));
}

class EZ2App extends StatelessWidget {
  final bool isSecure;
  const EZ2App({super.key, this.isSecure = true});

  // ── Shared text theme ────────────────────────────────────────
  static const _textTheme = TextTheme(
    bodyLarge: TextStyle(fontSize: 20, height: 1.5),
    bodyMedium: TextStyle(fontSize: 18, height: 1.5),
    bodySmall: TextStyle(fontSize: 16, height: 1.4),
    titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLocale()),
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
      ],
      child: Consumer<AppLocale>(
        builder: (context, locale, _) {
          return MaterialApp(
            title: 'EZ2 Lotto',
            debugShowCheckedModeBanner: false,
            themeMode: locale.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            // ── Light theme ──────────────────────────────────
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFC0392B),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF5F0E8),
              cardColor: Colors.white,
              dividerColor: Colors.grey.shade200,
              textTheme: _textTheme,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                color: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              navigationBarTheme: NavigationBarThemeData(
                height: context.isSmallPhone ? 60 : (context.isPhone ? 70 : 80),
                labelTextStyle: WidgetStateProperty.all(
                  TextStyle(
                      fontSize: context.smallFontSize,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // ── Dark theme ───────────────────────────────────
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFC0392B),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
              dividerColor: Colors.grey.shade800,
              textTheme: _textTheme,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                color: const Color(0xFF1E1E1E),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              navigationBarTheme: NavigationBarThemeData(
                height: context.isSmallPhone ? 60 : (context.isPhone ? 70 : 80),
                labelTextStyle: WidgetStateProperty.all(
                  TextStyle(
                      fontSize: context.smallFontSize,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            home: isSecure ? const _Shell() : const SecurityWarningScreen(),
          );
        },
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _idx = 0;

  static const _screens = <Widget>[
    TodayScreen(),
    HistoryScreen(),
    StatsScreen(),
    TicketScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined, size: 28),
      selectedIcon: Icon(Icons.today_rounded, size: 28),
      label: 'Results',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined, size: 28),
      selectedIcon: Icon(Icons.calendar_month_rounded, size: 28),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined, size: 28),
      selectedIcon: Icon(Icons.bar_chart_rounded, size: 28),
      label: 'Statistics',
    ),
    NavigationDestination(
      icon: Icon(Icons.confirmation_number_outlined, size: 28),
      selectedIcon: Icon(Icons.confirmation_number_rounded, size: 28),
      label: 'Ticket',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined, size: 28),
      selectedIcon: Icon(Icons.settings_rounded, size: 28),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // First-run loading screen: show while initial fetch is in progress
    if (prov.isRefreshing && prov.todayResult == null) {
      return const _FirstRunLoader();
    }

    return Scaffold(
      body: Column(
        children: [
          // Offline indicator banner
          if (prov.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: isDark ? Colors.orange.shade900 : Colors.orange.shade700,
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Wala kang internet - nagpapakita ng nakaimbak na datos',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _idx,
              children:
                  _screens.map((s) => RepaintBoundary(child: s)).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: _destinations,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        indicatorColor: const Color(0xFFC0392B).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 8,
      ),
    );
  }
}

// ── First-run loading screen ──────────────────────────────────
class _FirstRunLoader extends StatefulWidget {
  const _FirstRunLoader();
  @override
  State<_FirstRunLoader> createState() => _FirstRunLoaderState();
}

class _FirstRunLoaderState extends State<_FirstRunLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    final prov = context.read<AppProvider>();
    await prov.fetchToday();
    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isOffline = prov.isOffline;

    return Scaffold(
      backgroundColor: const Color(0xFFC0392B),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / App name
              const Text(
                'EZ2',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const Text(
                '2D LOTTO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 48),
              // Pulsing dots
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final v = ((_ctrl.value - delay).abs() < 0.5)
                        ? 1.0 - (_ctrl.value - delay).abs() * 2
                        : 0.3;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            Colors.white.withValues(alpha: v.clamp(0.3, 1.0)),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isOffline
                    ? 'Walang internet connection...'
                    : 'Kinukuha ang mga resulta...',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // Retry button for offline case
              if (isOffline && !_isRetrying)
                TextButton.icon(
                  onPressed: _handleRetry,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  label: const Text(
                    'Subukang Kumonekta Ulit',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              if (_isRetrying)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white70),
                  ),
                ),
              const SizedBox(height: 80),
              Text(
                '© ${DateTime.now().year} Mark Spencer D. Montalbo',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecurityWarningScreen extends StatelessWidget {
  const SecurityWarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.security_update_warning_rounded,
                  color: Color(0xFFE57373),
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Banta sa Seguridad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hindi maaring buksan ang app na ito sa rooted o jailbroken na device, o kung naka-on ang Developer Options, dahil sa banta sa seguridad ng iyong data.',
                  style: TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0392B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Isara ang App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
