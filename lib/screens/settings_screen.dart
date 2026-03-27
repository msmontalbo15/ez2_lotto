// lib/screens/settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../app_locale.dart';
import '../cache_service.dart';
import '../constants.dart';
import '../helpers.dart';
import '../responsive.dart';
import '../apk_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingUpdate = false;
  bool _isFetchingPastDraws = false;
  String _updateStatus = '';

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = '';
    });

    // Simulate cloud update check
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isCheckingUpdate = false;
      _updateStatus = 'You are running the latest version!';
    });
  }

  Future<void> _shareApp() async {
    try {
      // Get latest version info from Supabase
      final apkService = ApkService();
      final latestVersionInfo = await apkService.getLatestVersion();
      final version = latestVersionInfo?['version'] ?? '1.0.1';
      final downloadUrl = latestVersionInfo != null
          ? await apkService.getDownloadUrl(version)
          : 'https://play.google.com/store/apps/details?id=com.markspencer.ez2lotto';

      final shareText =
          'EZ2 Lotto - Check PCSO EZ2 results, history, and statistics!\n\n'
          '📱 Version $version available!\n'
          '🔗 Download: $downloadUrl\n\n'
          'Scan QR code or click link to install!';

      await Clipboard.setData(ClipboardData(text: shareText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App share link copied to clipboard!'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      // Fallback to original method if Supabase fails
      const shareText =
          'EZ2 Lotto - Check PCSO EZ2 results, history, and statistics!\n'
          'Download: https://play.google.com/store/apps/details?id=com.markspencer.ez2lotto';

      await Clipboard.setData(ClipboardData(text: shareText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App link copied to clipboard!'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    }
  }

  Future<void> _fetchAllPastDraws() async {
    setState(() {
      _isFetchingPastDraws = true;
    });

    try {
      final ph = getPHTime();
      int fetched = 0;
      int failed = 0;

      // Fetch last 30 days (reduce if still timing out)
      for (int i = 1; i <= 30; i++) {
        final date = ph.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        try {
          final response = await http
              .post(
                Uri.parse('$kSupabaseUrl/functions/v1/fetch-today'),
                headers: {
                  'Authorization': 'Bearer $kSupabaseAnonKey',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'date': dateStr}),
              )
              .timeout(const Duration(seconds: 60));

          if (response.statusCode == 200) {
            fetched++;
          } else {
            // Log the error response for debugging
            debugPrint(
                'Fetch error for $dateStr: ${response.statusCode} - ${response.body}');
            failed++;
          }
        } catch (e) {
          // Timeout or network error - count as failed but continue
          debugPrint('Exception for $dateStr: $e');
          failed++;
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() {
        _isFetchingPastDraws = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Fetched last 30 days: $fetched success, $failed failed'),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isFetchingPastDraws = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLocale>(
      builder: (context, appLocale, _) {
        final isDarkMode = appLocale.isDarkMode;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F0E8),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFF2C3E50),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(28)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      context.horizontalPadding,
                      context.headerPaddingTop,
                      context.horizontalPadding,
                      24,
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SETTINGS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.titleFontSize,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('App settings and options',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 15)),
                        ]),
                  ),
                ),

                SliverPadding(
                  padding: EdgeInsets.fromLTRB(context.horizontalPadding, 20,
                      context.horizontalPadding, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // App Settings Section
                      _SectionTitle(
                        icon: Icons.settings_applications_rounded,
                        title: 'APP SETTINGS',
                        color: const Color(0xFF1A5276),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        isDarkMode: isDarkMode,
                        children: [
                          // Language Toggle
                          _SettingsTile(
                            icon: Icons.language_rounded,
                            title: 'Language',
                            subtitle:
                                appLocale.isEnglish ? 'English' : 'Tagalog',
                            trailing: Switch(
                              value: appLocale.isEnglish,
                              onChanged: (value) {
                                appLocale.setLanguage(value);
                              },
                              activeThumbColor: const Color(0xFF27AE60),
                            ),
                            onTap: () {
                              appLocale.setLanguage(!appLocale.isEnglish);
                            },
                            isDarkMode: isDarkMode,
                          ),
                          const Divider(height: 1),
                          // Dark Mode Toggle
                          _SettingsTile(
                            icon: Icons.dark_mode_rounded,
                            title: 'Dark Mode',
                            subtitle: isDarkMode ? 'On' : 'Off',
                            trailing: Switch(
                              value: isDarkMode,
                              onChanged: (value) =>
                                  appLocale.setDarkMode(value),
                              activeThumbColor: const Color(0xFF27AE60),
                            ),
                            onTap: () {
                              appLocale.toggleDarkMode();
                            },
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Cloud Update Section
                      _SectionTitle(
                        icon: Icons.cloud_download_outlined,
                        title: 'CLOUD UPDATE',
                        color: const Color(0xFF27AE60),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        isDarkMode: isDarkMode,
                        children: [
                          _SettingsTile(
                            icon: Icons.system_update_alt_rounded,
                            title: 'Check for Updates',
                            subtitle: 'Check for app updates',
                            trailing: _isCheckingUpdate
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded,
                                    color: Color(0xFF27AE60)),
                            onTap: _isCheckingUpdate ? null : _checkForUpdate,
                            isDarkMode: isDarkMode,
                          ),
                          if (_updateStatus.isNotEmpty) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _updateStatus,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Share App Section
                      _SectionTitle(
                        icon: Icons.share_rounded,
                        title: 'SHARE APP',
                        color: const Color(0xFF3498DB),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        isDarkMode: isDarkMode,
                        children: [
                          _SettingsTile(
                            icon: Icons.share_rounded,
                            title: 'Share this App',
                            subtitle:
                                'Share via clipboard, bluetooth, or other apps',
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18),
                            onTap: _shareApp,
                            isDarkMode: isDarkMode,
                          ),
                          const Divider(height: 1),
                          _SettingsTile(
                            icon: Icons.link_rounded,
                            title: 'Copy App Link',
                            subtitle: 'Copy download link to clipboard',
                            trailing: const Icon(Icons.copy_rounded,
                                color: Color(0xFF3498DB)),
                            onTap: _shareApp,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Data Management Section
                      _SectionTitle(
                        icon: Icons.storage_outlined,
                        title: 'DATA MANAGEMENT',
                        color: const Color(0xFFE67E22),
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        isDarkMode: isDarkMode,
                        children: [
                          _SettingsTile(
                            icon: Icons.cached_rounded,
                            title: 'Clear Cache',
                            subtitle: 'Remove cached data',
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18),
                            onTap: () => _showClearCacheDialog(context),
                            isDarkMode: isDarkMode,
                          ),
                          const Divider(height: 1),
                          _SettingsTile(
                            icon: Icons.sync_alt_rounded,
                            title: 'Refresh Data',
                            subtitle: 'Reload all results from server',
                            trailing: const Icon(Icons.refresh_rounded,
                                color: Color(0xFFE67E22)),
                            onTap: () {
                              context.read<AppProvider>().fetchToday();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Refreshing data...'),
                                  backgroundColor: Color(0xFF27AE60),
                                ),
                              );
                            },
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // About Section
                      _SectionTitle(
                        icon: Icons.info_outline_rounded,
                        title: 'ABOUT',
                        color: const Color(0xFF9B59B6),
                      ),
                      const SizedBox(height: 12),
                      _DetailedAboutCard(
                        isDarkMode: isDarkMode,
                        onFetchPastDraws: _fetchAllPastDraws,
                        isFetchingPastDraws: _isFetchingPastDraws,
                      ),
                      const SizedBox(height: 24),

                      // App Info Footer
                      _AppInfoCard(isDarkMode: isDarkMode),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Text('Clear Cache?'),
        ]),
        content: const Text(
          'This will remove all cached data. You will need to reload data from the internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await CacheService.clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, color: color)),
    ]);
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDarkMode;

  const _SettingsCard({required this.children, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDarkMode;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFC0392B), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
      onTap: onTap,
    );
  }
}

class _DetailedAboutCard extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback? onFetchPastDraws;
  final bool isFetchingPastDraws;

  const _DetailedAboutCard({
    required this.isDarkMode,
    this.onFetchPastDraws,
    this.isFetchingPastDraws = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(children: [
        // App Info
        _SettingsTile(
          icon: Icons.apps_rounded,
          title: 'EZ2 Lotto',
          subtitle: '2D Lotto Results App - Created: March 2026',
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          onTap: () => _showAboutDialog(context),
          isDarkMode: isDarkMode,
        ),
        const Divider(height: 1),

        // Version / What's New
        _SettingsTile(
          icon: Icons.new_releases_rounded,
          title: 'Version 1.0.2',
          subtitle:
              "What's New: Added cloud update feature, improved performance, and bug fixes",
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          onTap: () => _showWhatsNewDialog(context),
          isDarkMode: isDarkMode,
        ),
        const Divider(height: 1),

        // Fetch Past Draws
        _SettingsTile(
          icon: Icons.download_rounded,
          title: 'Fetch Past Draws',
          subtitle: isFetchingPastDraws
              ? 'Fetching...'
              : 'Update all missing combo & winners',
          trailing: isFetchingPastDraws
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          onTap: isFetchingPastDraws ? null : () => onFetchPastDraws?.call(),
          isDarkMode: isDarkMode,
        ),
        const Divider(height: 1),

        // Developer
        _SettingsTile(
          icon: Icons.person_rounded,
          title: 'Developer',
          subtitle: 'Mark Spencer M. Montalbo',
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          onTap: () => _showDeveloperDialog(context),
          isDarkMode: isDarkMode,
        ),
      ]),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.apps_rounded, color: Color(0xFFC0392B)),
          SizedBox(width: 10),
          Text('EZ2 Lotto'),
        ]),
        content: const Text(
          'EZ2 Lotto is a mobile application that provides PCSO EZ2 lotto results, '
          'historical data, statistics, and ticket checking capabilities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _showWhatsNewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.new_releases_rounded, color: Color(0xFF27AE60)),
          SizedBox(width: 10),
          Text("What's New"),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.2'),
            SizedBox(height: 8),
            Text('• Cloud update feature'),
            Text('• Improved performance'),
            Text('• Bug fixes and enhancements'),
            SizedBox(height: 12),
            Text('Version 1.0.1',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('• Live EZ2 lotto results'),
            Text('• Historical results lookup'),
            Text('• Statistics and analysis'),
            Text('• Ticket checking feature'),
            Text('• Responsive design'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _showDeveloperDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.person_rounded, color: Color(0xFF3498DB)),
          SizedBox(width: 10),
          Text('Developer'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MARK SPENCER MONTALBO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Web Developer / Website Administrator',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text(
                '📍 Valenzuela City, Metro Manila, Philippines',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '📧 msmontalbo15@gmail.com',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'PROFESSIONAL SUMMARY',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF3498DB)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Web Developer with over 4 years of professional experience, specializing in WordPress, front-end development, and website administration.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'TECHNICAL SKILLS',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF3498DB)),
              ),
              const SizedBox(height: 4),
              const Text(
                '• Front-End: HTML5, CSS3, JavaScript\n'
                '• Back-End: PHP, CodeIgniter, MySQL\n'
                '• CMS: WordPress, Joomla, Oxygen Builder\n'
                '• Frameworks: React, Next.js, Node.js, Flutter\n'
                '• Tools: Git, cPanel, GTM, SEO',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 12),
              const Text(
                'LinkedIn: linkedin.com/in/mark-spencer-montalbo',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
              const Text(
                'Portfolio: msmontalbo15.github.io/portfolio/',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  final bool isDarkMode;

  const _AppInfoCard({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(children: [
        Image.asset(
          'assets/icon/app_icon.png',
          width: 64,
          height: 64,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.local_activity_rounded,
            size: 48,
            color: isDarkMode ? Colors.grey.shade600 : const Color(0xFFC0392B),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'EZ2 LOTTO',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 1.0.2',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '©2026 Mark Spencer M. Montalbo. All rights reserved.',
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isDarkMode ? Colors.grey.shade700 : const Color(0xFFFFEEBA),
            ),
          ),
          child: const Text(
            'DISCLAIMER: This app is for informational purposes only. '
            'We are not affiliated with PCSO in any way. '
            'Always verify your tickets at authorized PCSO outlets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF856404),
            ),
          ),
        ),
      ]),
    );
  }
}
