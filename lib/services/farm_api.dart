import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FarmApi {
  static const _key = 'api_base_url';
  static const _defaultBaseUrl = 'https://apple-farm-assistant-api.onrender.com';
  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;
  static bool get isOfflineOnly => _baseUrl.isEmpty;

  static Future<void> initialize() async {
    final p = await SharedPreferences.getInstance();
    _baseUrl = (p.getString(_key) ?? _defaultBaseUrl)
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = normalized.isEmpty ? _defaultBaseUrl : normalized;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, _baseUrl);
  }

  Future<bool> health() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
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
        'tasks': [
          {'title': '과수원 상태 확인', 'scheduled_at': '오늘', 'priority': 1},
          {'title': '잡초 및 병해충 예찰', 'scheduled_at': '오전', 'priority': 2}
        ],
        'best_work_times': [
          {
            'time': '08:00',
            'temp': 22,
            'wind': 1.5,
            'rain_probability': 10,
            'grade': '참고',
            'score': 80
          },
          {
            'time': '17:00',
            'temp': 25,
            'wind': 2.0,
            'rain_probability': 20,
            'grade': '참고',
            'score': 75
          }
        ]
      };

  Future<Map<String, dynamic>> dashboard(String orchard) async {
    try {
      final u = Uri.parse('$_baseUrl/api/dashboard')
          .replace(queryParameters: {'orchard': orchard});
      final r = await http.get(u).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return _demoDashboard(orchard);
  }

  Future<List<dynamic>> orchards() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/api/orchards'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return [
      {'name': 'A과수원', 'variety': '후지', 'offline_mode': true}
    ];
  }

  Future<List<dynamic>> tasks(String orchard) async {
    try {
      final u = Uri.parse('$_baseUrl/api/tasks')
          .replace(queryParameters: {'orchard': orchard});
      final r = await http.get(u).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return [];
  }

  Future<bool> addTask({
    required String orchard,
    required String title,
    String category = '일반',
    int priority = 2,
    String? scheduledAt,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl/api/tasks'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orchard': orchard,
              'title': title,
              'category': category,
              'priority': priority,
              'scheduled_at': scheduledAt,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> completeTask(int taskId) async {
    try {
      final r = await http
          .post(Uri.parse('$_baseUrl/api/tasks/$taskId/complete'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> coach() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/api/coach'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return {
      'offline_mode': true,
      'best_hours': [
        {'hour': 8, 'samples': 0, 'score': 82},
        {'hour': 9, 'samples': 0, 'score': 80},
        {'hour': 16, 'samples': 0, 'score': 76}
      ],
      'policy': '오프라인 기본값입니다. 서버 연결 후 실제 작업기록으로 개인화됩니다.'
    };
  }

  Future<Map<String, dynamic>> survivorAdvice(
      Map<String, dynamic> data) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl/api/weeds/survivor-advice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return {
      'offline_mode': true,
      'possible_causes': [
        '잡초 종류 오인 가능성',
        '처리 시 잡초가 너무 자랐을 가능성',
        '살포 균일도 문제 가능성',
        '같은 작용기작 반복 가능성'
      ],
      'actions': [
        '살아남은 잡초의 종류와 생육단계를 다시 확인하세요.',
        '살포 당시 비·바람·노즐·압력·사각지대를 점검하세요.',
        '농촌진흥청 PSIS에서 사과 등록 여부와 대상 잡초, 사용시기, 작용기작을 확인하세요.',
        '임의 증량이나 짧은 간격의 반복 살포는 피하고 예초·멀칭 같은 비화학적 방법도 함께 검토하세요.'
      ]
    };
  }
}
