import 'dart:convert';
import 'package:http/http.dart' as http;
import 'farm_api.dart';

class RecommendationDiagnosisApi {
  Future<Map<String, dynamic>> assess({
    required String orchard,
    required String specificThreat,
    required String threatType,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('${FarmApi.baseUrl}/api/diagnosis/recommendation-assess'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orchard': orchard,
              'specific_threat': specificThreat,
              'threat_type': threatType,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      return {'error': '서버 응답 ${r.statusCode}'};
    } catch (_) {
      return {'error': '추천 진단 API 연결 실패'};
    }
  }
}
