// lib/constants.dart

import 'package:flutter/material.dart';

// ── Colors ───────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFFB71C1C);
  static const primaryDark = Color(0xFF8B0000);
  static const primaryLight = Color(0xFFC62828);
  static const accent = Color(0xFFE65100);
  static const amber = Color(0xFFFFB300);
  static const green = Color(0xFF2E7D32);
  static const greenLight = Color(0xFFE8F5E9);
  static const blue = Color(0xFF0277BD);
  static const bgGradStart = Color(0xFFFFF8E1);
  static const bgGradMid = Color(0xFFFFFDE7);
  static const bgGradEnd = Color(0xFFFCE4EC);
  static const cardBorder = Color(0xFFE0E0E0);
  static const textDark = Color(0xFF111111);
  static const textMid = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const ballOrange1 = Color(0xFFFFFDE7);
  static const ballOrange2 = Color(0xFFFFB300);
  static const ballOrange3 = Color(0xFFE65100);
  static const ballOrangeBorder = Color(0xFFBF360C);
  static const ballGreen1 = Color(0xFFF0FFF4);
  static const ballGreen2 = Color(0xFF00C853);
  static const ballGreen3 = Color(0xFF1B5E20);
}

// ── Draw schedule ─────────────────────────────────────────────
class DrawSlot {
  final String key;
  final String emoji;
  final String label;
  final int drawHour;
  const DrawSlot(this.key, this.emoji, this.label, this.drawHour);
}

const kDrawSchedule = [
  DrawSlot('2pm', '🌤️', '2:00 PM', 14),
  DrawSlot('5pm', '🌇', '5:00 PM', 17),
  DrawSlot('9pm', '🌙', '9:00 PM', 21),
];

// ── Filipino month names ───────────────────────────────────────
const kMonthsFil = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// ── Supabase config ───────────────────────────────────────────
//
// SECURITY: Inject credentials at build time via --dart-define.
//
// Local dev:
//   flutter run \
//     --dart-define=SUPABASE_URL=https://votvvysgaiaycmbgeayh.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<key>
//
// Release build (CI/CD — never commit actual keys):
//   flutter build apk --release --obfuscate --split-debug-info=build/symbols \
//     --dart-define=SUPABASE_URL=$SUPABASE_URL \
//     --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
//
// The fallback strings below are for local development ONLY.
// Remove them before distributing a production build.
//
// ignore: do_not_use_environment
const kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://votvvysgaiaycmbgeayh.supabase.co', // DEV ONLY
);
// ignore: do_not_use_environment
const kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdHZ2eXNnYWlheWNtYmdlYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxODQ0NDgsImV4cCI6MjA4OTc2MDQ0OH0.ll3My0vVjBYW6Qnk49vplMH_K1OOY6prj--Gaz3uCdw', // DEV ONLY
);
