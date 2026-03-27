// lib/apk_service.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApkService {
  /// Get the latest version info from Supabase
  Future<Map<String, dynamic>?> getLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$kSupabaseUrl/rest/v1/app_versions?select=*&limit=1&order=created_at.desc'),
        headers: {
          'Authorization': 'Bearer $kSupabaseAnonKey',
          'apikey': kSupabaseAnonKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = _parseJson(response.body);
        if (data.isNotEmpty) {
          return Map<String, dynamic>.from(data.first);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting latest version: $e');
      return null;
    }
  }

  /// Get the download URL for a specific version
  Future<String?> getDownloadUrl(String version) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$kSupabaseUrl/rest/v1/app_versions?select=download_url&version=eq.$version'),
        headers: {
          'Authorization': 'Bearer $kSupabaseAnonKey',
          'apikey': kSupabaseAnonKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = _parseJson(response.body);
        if (data.isNotEmpty) {
          return data.first['download_url'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting download URL: $e');
      return null;
    }
  }

  dynamic _parseJson(String body) {
    try {
      return body.isEmpty ? [] : const JsonDecoder().convert(body);
    } catch (e) {
      return [];
    }
  }
}

class JsonDecoder {
  const JsonDecoder();
  dynamic convert(String input) {
    // Simple JSON parse - in production consider using dart:convert
    if (input == 'null') return null;
    if (input == '[]') return [];
    if (input.startsWith('[')) {
      // Basic array parsing
      return _parseJsonArray(input);
    }
    if (input.startsWith('{')) {
      return _parseJsonObject(input);
    }
    return input;
  }

  List<dynamic> _parseJsonArray(String input) {
    // Remove brackets
    final content = input.substring(1, input.length - 1).trim();
    if (content.isEmpty) return [];

    // Simple object parsing
    final List<dynamic> result = [];
    int depth = 0;
    int start = 0;

    for (int i = 0; i < content.length; i++) {
      if (content[i] == '{') depth++;
      if (content[i] == '}') depth--;

      if (depth == 0 && content[i] == ',') {
        result.add(_parseJsonObject(content.substring(start, i).trim()));
        start = i + 1;
      }
    }

    if (start < content.length) {
      result.add(_parseJsonObject(content.substring(start).trim()));
    }

    return result;
  }

  Map<String, dynamic> _parseJsonObject(String input) {
    final Map<String, dynamic> result = {};
    if (input.isEmpty || input == '{}') return result;

    // Remove braces
    final content = input.substring(1, input.length - 1).trim();

    // Simple key-value parsing
    final pattern =
        RegExp(r'"([^"]+)":\s*("[^"]*"|\d+|true|false|null|\{[^}]*\})');
    for (final match in pattern.allMatches(content)) {
      final key = match.group(1)!;
      final value = match.group(2)!;

      if (value.startsWith('"')) {
        result[key] = value.substring(1, value.length - 1);
      } else if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else if (value == 'null') {
        result[key] = null;
      } else if (value == '{}') {
        result[key] = <String, dynamic>{};
      } else {
        result[key] = int.tryParse(value) ?? double.tryParse(value) ?? value;
      }
    }

    return result;
  }
}
