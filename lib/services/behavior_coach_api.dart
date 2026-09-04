import 'dart:convert';
import 'package:http/http.dart' as http;
import 'farm_api.dart';

class BehaviorCoachApi {
  Future<bool> saveCheckin(Map<String, dynamic> payload) async {
    try {
      final r = await http
          .post(
            Uri.parse('${FarmApi.baseUrl}/api/coach/behavior-checkin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> analysis() async {
    try {
      final r = await http
          .get(Uri.parse('${FarmApi.baseUrl}/api/coach/behavior-analysis'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
    } catch (_) {}
    return {
      'error': '행동 코치 서버 연결 실패',
      'sample_count': 0,
      'patterns': [],
      'interventions': [],
    };
  }
}
