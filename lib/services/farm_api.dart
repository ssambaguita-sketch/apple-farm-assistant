import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'orchard_selection.dart';

class FarmApi {
  static const _key = 'api_base_url';
  static const _defaultBaseUrl = 'https://apple-farm-assistant-api.onrender.com';
  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;
  static bool get isOfflineOnly => _baseUrl.isEmpty;

  static Future<void> initialize() async {
    final p = await SharedPreferences.getInstance();
    final saved = (p.getString(_key) ?? _defaultBaseUrl).trim();
    _baseUrl = saved.contains('10.0.2.2') || saved.isEmpty
        ? _defaultBaseUrl
        : saved.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = normalized.isEmpty ? _defaultBaseUrl : normalized;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, _baseUrl);
  }

  String _selected(String fallback) => OrchardSelection.name.trim().isNotEmpty ? OrchardSelection.name : fallback;

  Future<bool> health() async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 25));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> diagnostics(String orchard) async {
    final selected = _selected(orchard);
    final result = <String, dynamic>{
      'server': false,
      'database': false,
      'kma_configured': false,
      'weather': false,
      'weather_source': 'unknown',
      'tasks': false,
      'coach': false,
      'messages': <String>[],
    };
    try {
      final r = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final j = Map<String, dynamic>.from(jsonDecode(r.body));
        result['server'] = j['ok'] == true;
        result['database'] = j['database_ok'] == true;
        result['kma_configured'] = j['kma_configured'] == true;
        result['server_version'] = j['version'];
        result['database_type'] = j['database'];
      }
    } catch (_) {
      (result['messages'] as List<String>).add('서버 상태 확인 실패');
    }
    try {
      final u = Uri.parse('$_baseUrl/api/weather').replace(queryParameters: {'orchard': selected});
      final r = await http.get(u).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final j = Map<String, dynamic>.from(jsonDecode(r.body));
        result['weather'] = true;
        result['weather_source'] = j['weather_source'] ?? 'unknown';
        result['weather_warning'] = j['weather_warning'];
        result['weather_grid'] = j['grid'];
      }
    } catch (_) {
      (result['messages'] as List<String>).add('날씨 API 확인 실패');
    }
    try {
      final u = Uri.parse('$_baseUrl/api/tasks').replace(queryParameters: {'orchard': selected});
      final r = await http.get(u).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        result['tasks'] = true;
        final data = jsonDecode(r.body);
        result['task_count'] = data is List ? data.length : 0;
      }
    } catch (_) {
      (result['messages'] as List<String>).add('작업 API 확인 실패');
    }
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/coach')).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) result['coach'] = true;
    } catch (_) {
      (result['messages'] as List<String>).add('코치 API 확인 실패');
    }
    result['orchard'] = selected;
    return result;
  }

  Future<bool> saveOrchardLocation({
    required String orchard,
    required double lat,
    required double lon,
  }) async {
    final selected = _selected(orchard);
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl/api/orchards/location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'orchard': selected, 'lat': lat, 'lon': lon}),
          )
          .timeout(const Duration(seconds: 25));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _demoDashboard(String orchard) => {
        'offline_mode': true,
        'orchard': orchard,
        'risk_score': 0,
        'profit': 0,
        'weather_source': 'demo',
        'weather_warning': '서버 또는 실제 기상 데이터에 연결되지 않았습니다.',
        'tasks': [],
        'best_work_times': []
      };

  Future<Map<String, dynamic>> dashboard(String orchard) async {
    final selected = _selected(orchard);
    try {
      final u = Uri.parse('$_baseUrl/api/dashboard').replace(queryParameters: {'orchard': selected});
      final r = await http.get(u).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
    } catch (_) {}
    return _demoDashboard(selected);
  }

  Future<List<dynamic>> orchards() async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/orchards')).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> tasks(String orchard) async {
    final selected = _selected(orchard);
    try {
      final u = Uri.parse('$_baseUrl/api/tasks').replace(queryParameters: {'orchard': selected});
      final r = await http.get(u).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return [];
  }

  Future<bool> addTask({required String orchard, required String title, String category = '일반', int priority = 2, String? scheduledAt}) async {
    final selected = _selected(orchard);
    try {
      final r = await http
          .post(Uri.parse('$_baseUrl/api/tasks'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({
        'orchard': selected,
        'title': title,
        'category': category,
        'priority': priority,
        'scheduled_at': scheduledAt,
      })).timeout(const Duration(seconds: 20));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> completeTask(int taskId) async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/api/tasks/$taskId/complete')).timeout(const Duration(seconds: 20));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> coach() async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/coach')).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
    } catch (_) {}
    return {
      'offline_mode': true,
      'best_hours': [
        {'hour': 8, 'samples': 0, 'score': 82},
        {'hour': 9, 'samples': 0, 'score': 80},
        {'hour': 16, 'samples': 0, 'score': 76}
      ],
      'policy': '오프라인 기본값입니다.'
    };
  }

  Future<Map<String, dynamic>> survivorAdvice(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['orchard'] = OrchardSelection.name;
    try {
      final r = await http
          .post(Uri.parse('$_baseUrl/api/weeds/survivor-advice'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
    } catch (_) {}
    return {
      'offline_mode': true,
      'possible_causes': ['서버 연결 실패'],
      'actions': ['네트워크 연결 후 다시 시도하세요.']
    };
  }
}
