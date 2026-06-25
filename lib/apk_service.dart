// lib/apk_service.dart
//
// SECURITY REWRITE:
//  - Removed hand-rolled JsonDecoder (regex-based, ReDoS risk)
//  - All calls now go through the Supabase Flutter SDK (no raw HTTP + anon key in headers)
//  - dart:convert used directly for any JSON needs

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApkService {
  static final _db = Supabase.instance.client;

  /// Returns the latest app version entry from the [app_versions] table.
  Future<Map<String, dynamic>?> getLatestVersion() async {
    try {
      final data = await _db
          .from('app_versions')
          .select('*')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[ApkService] getLatestVersion error: $e');
      return null;
    }
  }

  /// Returns the download URL for [version], or null if not found.
  Future<String?> getDownloadUrl(String version) async {
    try {
      final data = await _db
          .from('app_versions')
          .select('download_url')
          .eq('version', version)
          .maybeSingle();
      return data?['download_url'] as String?;
    } catch (e) {
      debugPrint('[ApkService] getDownloadUrl error: $e');
      return null;
    }
  }
}
