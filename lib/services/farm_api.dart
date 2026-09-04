import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class FarmApi {
  final String baseUrl;
  FarmApi({this.baseUrl = 'http://10.0.2.2:8000'});

  Map<String, dynamic> _demoDashboard(String orchard) => {
        'offline_mode': true,
        'orchard': orchard,
        'risk_score': 12,
        'profit': 0,
        'tasks': [
          {
            'title': '과수원 상태 확인',
            'scheduled_at': '오늘',
            'priority': 1
          },
          {
            'title': '잡초 및 병해충 예찰',
            'scheduled_at': '오전',
            'priority': 2
          }
        ],
        'best_work_times': [
          {
            'time': '08:00',
            'temp': 22,
            'wind': 1.5,
            'rain_probability': 10,
            'grade': '적합',
            'score': 92
          },
          {
            'time': '09:00',
            'temp': 24,
            'wind': 2.0,
            'rain_probability': 10,
            'grade': '적합',
            'score': 88
          },
          {
            'time': '17:00',
            'temp': 25,
            'wind': 2.5,
            'rain_probability': 20,
            'grade': '적합',
            'score': 82
          }
        ]
      };

  Future<Map<String, dynamic>> dashboard(String orchard) async {
    try {
      final u = Uri.parse('$baseUrl/api/dashboard')
          .replace(queryParameters: {'orchard': orchard});
      final r = await http.get(u).timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return _demoDashboard(orchard);
  }

  Future<List<dynamic>> orchards() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/orchards'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return [
      {'name': 'A과수원', 'variety': '후지', 'offline_mode': true}
    ];
  }

  Future<Map<String, dynamic>> coach() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/coach'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return {
      'offline_mode': true,
      'best_hours': [
        {'hour': 8, 'samples': 0, 'score': 85},
        {'hour': 9, 'samples': 0, 'score': 82},
        {'hour': 17, 'samples': 0, 'score': 78}
      ],
      'policy': '오프라인 기본 추천값입니다. 작업기록이 쌓이면 서버 연결 후 개인화할 수 있습니다.'
    };
  }

  Future<Map<String, dynamic>> survivorAdvice(
      Map<String, dynamic> data) async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/api/weeds/survivor-advice'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return {
      'offline_mode': true,
      'possible_causes': [
        '잡초 종류 오인 가능성',
        '처리 시 잡초가 너무 자랐을 가능성',
        '약액 도달·살포 균일도 문제 가능성',
        '같은 작용기작의 반복 사용 가능성'
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
