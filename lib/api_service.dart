// lib/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'helpers.dart';
import 'models.dart';

class ApiService {
  static final _client = http.Client();

  // ── Fetch today's results from DB (fast read) ─────────────
  static Future<DayResult?> fetchTodayFromDB() async {
    try {
      final ph = getPHTime();
      final iso = toISODate(ph);
      final short = toShortDate(ph);
      final day = toDayName(ph);

      final res = await _client
          .get(Uri.parse('$kApiBase/results?date=$iso'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return DayResult.fromDayJson(json, short, day);
    } catch (_) {
      return null;
    }
  }

  // ── Trigger background fetch (cron endpoint) ──────────────
  // Returns list of newly saved slots e.g. ['2pm', '5pm']
  static Future<List<String>> triggerFetchToday() async {
    try {
      final res = await _client
          .post(Uri.parse('$kApiBase/fetch-today'))
          .timeout(
              const Duration(seconds: 60)); // Claude search can take a while

      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return List<String>.from(json['newlySaved'] ?? []);
    } catch (_) {
      return [];
    }
  }

  // ── Fetch a full month from DB ─────────────────────────────
  static Future<List<DayResult>> fetchMonth(String monthKey) async {
    final res = await _client
        .get(Uri.parse('$kApiBase/results?month=$monthKey'))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Failed to load month $monthKey: ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (json['rows'] as List<dynamic>? ?? [])
        .map((r) => DayResult.fromMonthJson(r as Map<String, dynamic>))
        .toList();
    return rows;
  }

  // ── Read ticket image via Claude API ──────────────────────
  // Returns {'numbers': 'XX-YY', 'date': '...', 'draw': '...'}
  // Pass your Anthropic API key — keep it server-side in production!
  static Future<Map<String, dynamic>?> readTicketImage(
    String base64Image,
    String mimeType,
    String anthropicApiKey,
  ) async {
    try {
      final res = await _client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': anthropicApiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-sonnet-4-20250514',
              'max_tokens': 500,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image',
                      'source': {
                        'type': 'base64',
                        'media_type': mimeType,
                        'data': base64Image,
                      },
                    },
                    {
                      'type': 'text',
                      'text':
                          '''PCSO EZ2 ticket. Respond ONLY valid JSON (no markdown):
{"numbers":"XX-YY","date":"Mon DD, YYYY","draw":"2:00 PM or 5:00 PM or 9:00 PM or unknown","type":"straight or rambolito or unknown"}
Numbers must be XX-YY with 01-31. Use null if unclear.''',
                    },
                  ],
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final blocks = (data['content'] as List?)
          ?.where((b) => b['type'] == 'text')
          .toList();
      if (blocks == null || blocks.isEmpty) return null;
      final text = blocks.last['text'] as String;
      final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
